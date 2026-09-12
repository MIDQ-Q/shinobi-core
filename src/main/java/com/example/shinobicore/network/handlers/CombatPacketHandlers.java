package com.example.shinobicore.network.handlers;

import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.network.PacketValidator;
import com.example.shinobicore.network.PacketRateLimiter;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.combat.TaijutsuCombo;
import com.example.shinobicore.combat.MeleeHitDetection;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.combat.KenjutsuFormulas;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

public final class CombatPacketHandlers {
    private CombatPacketHandlers() {}

    public static void register() {
        registerTaijutsuAttack();
        registerTaijutsuKick();
        registerTaijutsuStyle();
        registerKatanaAttack();
        registerKatanaStance();
        registerKatanaDeflect();
    }

    private static void registerTaijutsuAttack() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.TAIJUTSU_ATTACK_ID, (server, player, handler, buf, responseSender) -> {
            final int clientComboStep = buf.readInt();
            final String styleId = PacketValidator.safeReadString(buf);
            if (!PacketValidator.validComboStep(clientComboStep)) {
                PacketValidator.logRejection(player, "TAIJUTSU_ATTACK", "invalid combo step");
                return;
            }
            if (!PacketValidator.validStyleId(styleId)) {
                PacketValidator.logRejection(player, "TAIJUTSU_ATTACK", "invalid style");
                return;
            }
            // ADR-004: клиент сообщает только факты (шаг, стиль). Авторитет — сервер.

            server.execute(() -> {
                if (player.getWorld().isClient()) return;
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                TaijutsuStyle style = TaijutsuStyle.fromId(styleId);
                long now = System.currentTimeMillis();
                long lastAttack = data.getLastAttackTimeMs();
                long timeoutMs = com.example.shinobicore.combat.ComboMachine.timeoutMs(
                        TreePassives.collectServer(data).comboTimeoutBonus);

                // P0-3 (1/3): сброс по таймауту ДО сравнения шага.
                // Раньше сравнение шло первым, поэтому serverComboStep застревал навсегда.
                if (now - lastAttack > timeoutMs && data.getServerComboStep() > 0) {
                    data.resetCombo();
                }
                int serverStep = data.getServerComboStep();

                // P0-3 (2/3): мягкое прощение рассинхрона на 1 шаг внутри окна.
                if (clientComboStep != serverStep) {
                    boolean forgivable = Math.abs(clientComboStep - serverStep) == 1
                            && (now - lastAttack) <= timeoutMs;
                    if (!forgivable) {
                        ShinobiCore.LOGGER.warn("[ANTICHEAT] Player {} sent comboStep={}, expected={}",
                                player.getName().getString(), clientComboStep, serverStep);
                        sendComboSync(player, serverStep, serverStep, false,
                                com.example.shinobicore.combat.ComboMachine.RejectReason.DESYNC);
                        return;
                    }
                    ShinobiCore.LOGGER.debug("[COMBO] forgiving desync: client={} server={}",
                            clientComboStep, serverStep);
                }

                if (data.isExhausted()) {
                    sendComboSync(player, serverStep, serverStep, false,
                            com.example.shinobicore.combat.ComboMachine.RejectReason.EXHAUSTED);
                    return;
                }
                if (data.getCurrentChakra() <= 0) {
                    sendComboSync(player, serverStep, serverStep, false,
                            com.example.shinobicore.combat.ComboMachine.RejectReason.EXHAUSTED);
                    return;
                }

                int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
                int cooldownMs = TaijutsuFormulas.attackCooldownTicks(style, data.isChakraMode(), taijutsuLevel) * 50;
                if (now - lastAttack < cooldownMs - com.example.shinobicore.combat.ComboMachine.CLOCK_TOLERANCE_MS) {
                    sendComboSync(player, serverStep, serverStep, false,
                            com.example.shinobicore.combat.ComboMachine.RejectReason.COOLDOWN);
                    return;
                }

                boolean chakraMode = data.isChakraMode();
                float damage = TaijutsuFormulas.computeDamage(taijutsuLevel, style, chakraMode, serverStep, data.isExhausted());
                damage *= com.example.shinobicore.combat.FrenzyTracker.damageMultiplier(player);   // Combat Pack v1: раж (тай-дзюцу)
                float knockback = TaijutsuCombo.getKnockback(serverStep);
                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = MeleeHitDetection.findTargetsInCone(
                        (ServerWorld) player.getWorld(), player, look);
                MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);

                // Спринт 8: хитстоп из таблицы шагов вместо фиксированных 80/160 мс.
                int hsA = com.example.shinobicore.combat.ComboMachine.hitStopAttackerMs(serverStep);
                int hsT = com.example.shinobicore.combat.ComboMachine.hitStopTargetMs(serverStep);
                for (LivingEntity t : targets) ShinobiCore.broadcastHitStop(player, t, hsA, hsT);

                boolean hitSomething = !targets.isEmpty();
                data.setFatigue(data.getFatigue() + style.getFatiguePerHit());
                // ADR-011 (D-2): lastAttackTime обновляется ВСЕГДА — промах продлевает
                // окно комбо, но серию не продвигает.
                data.setLastAttackTimeMs(now);
                if (hitSomething) data.advanceComboStep();
                data.setCurrentStyleId(styleId);

                // P0-3 (3/3): сервер ОБЯЗАН подтвердить шаг.
                sendComboSync(player, serverStep, data.getServerComboStep(), hitSomething,
                        hitSomething
                                ? com.example.shinobicore.combat.ComboMachine.RejectReason.OK
                                : com.example.shinobicore.combat.ComboMachine.RejectReason.WHIFF);
            });
        });
    }

    /**
     * P0-3: подтверждение шага комбо клиенту.
     *
     * Клиент НЕ инкрементирует шаг сам (прямой комментарий в TaijutsuClientHandler:
     * "Ждем пакет S2C_COMBO_SYNC от сервера"), а сервер этот пакет не отправлял.
     * В результате serverComboStep застревал на 1 и КАЖДЫЙ следующий удар
     * отклонялся с предупреждением [ANTICHEAT]. Бой голыми руками был сломан.
     *
     * Формат: int authoritativeStep, int nextStep, boolean success, byte rejectReason
     */
    private static void sendComboSync(ServerPlayerEntity player, int authoritativeStep,
                                      int nextStep, boolean success,
                                      com.example.shinobicore.combat.ComboMachine.RejectReason reason) {
        net.minecraft.network.PacketByteBuf buf =
                new net.minecraft.network.PacketByteBuf(io.netty.buffer.Unpooled.buffer());
        buf.writeInt(authoritativeStep);
        buf.writeInt(nextStep);
        buf.writeBoolean(success);
        buf.writeByte(reason.code());
        ServerPlayNetworking.send(player, ModPackets.COMBO_SYNC_ID, buf);
    }

    /** P1-5: то же самое для катаны, но отдельным каналом. */
    private static void sendKatanaComboSync(ServerPlayerEntity player, int authoritativeStep,
                                            int nextStep, boolean success,
                                            com.example.shinobicore.combat.ComboMachine.RejectReason reason) {
        net.minecraft.network.PacketByteBuf buf =
                new net.minecraft.network.PacketByteBuf(io.netty.buffer.Unpooled.buffer());
        buf.writeInt(authoritativeStep);
        buf.writeInt(nextStep);
        buf.writeBoolean(success);
        buf.writeByte(reason.code());
        ServerPlayNetworking.send(player, ModPackets.KATANA_COMBO_SYNC_ID, buf);
    }
    private static void registerTaijutsuKick() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.TAIJUTSU_KICK_ID, (server, player, handler, buf, responseSender) -> {
            final String styleId = PacketValidator.safeReadString(buf);
            server.execute(() -> {
                if (player.getWorld().isClient()) return;
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                TaijutsuStyle style = TaijutsuStyle.fromId(styleId);
                int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
                boolean chakraMode = data.isChakraMode();
                float baseDamage = TaijutsuFormulas.computeDamage(taijutsuLevel, style, chakraMode, 2, data.isExhausted());
                float damage = baseDamage * 1.5f;
                float knockback = 1.5f;
                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = MeleeHitDetection.findTargetsInCone(
                    (ServerWorld) player.getWorld(), player, look);
                MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);
                for (LivingEntity t : targets) ShinobiCore.broadcastHitStop(player, t, 80, 160);
                data.setFatigue(data.getFatigue() + style.getFatiguePerHit() * 1.5f);
            });
        });
    }

    private static void registerTaijutsuStyle() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.TAIJUTSU_STYLE_ID, (server, player, handler, buf, responseSender) -> {
            final String newStyleId = PacketValidator.safeReadString(buf);
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                TaijutsuStyle style = TaijutsuStyle.fromId(newStyleId);
                int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
                if (style == TaijutsuStyle.STRONG_FIST && !TaijutsuFormulas.canUseStrongFist(taijutsuLevel)) {
                    player.sendMessage(Text.literal("\u00a7cYou need Taijutsu level " +
                        TaijutsuFormulas.strongFistUnlockLevel() + " to use Strong Fist!"), false);
                    return;
                }
                data.setCurrentStyleId(newStyleId);
                ShinobiCore.sendBodySync(player);
                player.sendMessage(Text.literal("\u00a7aStyle changed to: " + style.getId()), false);
            });
        });
    }

    private static void registerKatanaAttack() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.KATANA_ATTACK_ID, (server, player, handler, buf, responseSender) -> {
            final int stepParam = buf.readInt();
            final String stanceParam = PacketValidator.safeReadString(buf);
            if (!PacketValidator.validComboStep(stepParam)) return;
            if (!PacketValidator.validStyleId(stanceParam)) return;
            if (!PacketRateLimiter.allow(player.getUuid(), "KATANA_ATTACK", 150)) return;

            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                KenjutsuStance stance = KenjutsuStance.fromId(stanceParam);
                long now = System.currentTimeMillis();
                long last = data.getKatanaLastAttackMs();
                long timeoutMs = com.example.shinobicore.combat.ComboMachine.TIMEOUT_BASE_MS;

                // P1-5 (1/3): сброс по таймауту ДО сравнения шага (было после).
                if (now - last > timeoutMs && data.getKatanaComboStep() != 0) {
                    data.setKatanaComboStep(0);
                }
                int serverStep = data.getKatanaComboStep();

                if (data.isKatanaDeflectHeld()) {
                    sendKatanaComboSync(player, serverStep, serverStep, false,
                            com.example.shinobicore.combat.ComboMachine.RejectReason.BLOCKING);
                    return;
                }
                if (data.isExhausted()) {
                    sendKatanaComboSync(player, serverStep, serverStep, false,
                            com.example.shinobicore.combat.ComboMachine.RejectReason.EXHAUSTED);
                    return;
                }
                // P1-5 (2/3): прощение рассинхрона на 1 шаг внутри окна.
                if (stepParam != serverStep) {
                    boolean forgivable = Math.abs(stepParam - serverStep) == 1 && (now - last) <= timeoutMs;
                    if (!forgivable) {
                        ShinobiCore.LOGGER.warn("[ANTICHEAT] Katana: player {} sent step={}, expected={}",
                                player.getName().getString(), stepParam, serverStep);
                        sendKatanaComboSync(player, serverStep, serverStep, false,
                                com.example.shinobicore.combat.ComboMachine.RejectReason.DESYNC);
                        return;
                    }
                }
                if (now - last < KenjutsuFormulas.cooldownMs(stance)
                        - com.example.shinobicore.combat.ComboMachine.CLOCK_TOLERANCE_MS) {
                    sendKatanaComboSync(player, serverStep, serverStep, false,
                            com.example.shinobicore.combat.ComboMachine.RejectReason.COOLDOWN);
                    return;
                }

                int step = serverStep;
                int tai = data.getStatLevel(StatType.TAIJUTSU);
                float damage = KenjutsuFormulas.computeDamage(tai, stance, data.isChakraMode(), step, data.isExhausted());
                damage *= com.example.shinobicore.combat.FrenzyTracker.damageMultiplier(player);   // Combat Pack v1: раж (катана)

                // Q-A: iaijutsu перенесён из удалённой стойки IAI в AGGRESSIVE.
                if (stance == KenjutsuStance.AGGRESSIVE
                        && now - last > com.example.shinobicore.combat.KenjutsuBalance.IAIJUTSU_IDLE_MS) {
                    damage *= com.example.shinobicore.combat.KenjutsuBalance.IAIJUTSU_MULTIPLIER;
                    player.sendMessage(Text.literal("\u00a76IAIJUTSU!"), false);
                    player.playSound(net.minecraft.sound.SoundEvents.ENTITY_PLAYER_ATTACK_CRIT, 1.0f, 0.8f);
                    if (player.getWorld() instanceof ServerWorld sw3) {
                        sw3.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT,
                                player.getX(), player.getY() + 1, player.getZ(), 20, 0.5, 0.5, 0.5, 0.1);
                    }
                }

                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = step == 3
                        ? KenjutsuFormulas.findInRadius((ServerWorld) player.getWorld(), player, 3.5)
                        : KenjutsuFormulas.findTargetsInCone((ServerWorld) player.getWorld(), player, look, 3.75, 100);

                int hsA = com.example.shinobicore.combat.ComboMachine.hitStopAttackerMs(step);
                int hsT = com.example.shinobicore.combat.ComboMachine.hitStopTargetMs(step);
                for (LivingEntity t : targets) {
                    t.damage(player.getDamageSources().playerAttack(player), damage);
                    Vec3d kb = t.getPos().subtract(player.getPos()).normalize()
                            .multiply(com.example.shinobicore.combat.ComboMachine.knockback(step));
                    t.addVelocity(kb.x, 0.2, kb.z);
                    t.velocityModified = true;
                    ShinobiCore.broadcastHitStop(player, t, hsA, hsT);
                }

                boolean hitSomething = !targets.isEmpty();
                data.setFatigue(data.getFatigue() + 1.5f);
                // ADR-011 (D-2): время обновляем всегда, шаг — только при попадании.
                data.setKatanaLastAttackMs(now);
                if (hitSomething) {
                    data.setKatanaComboStep(com.example.shinobicore.combat.ComboMachine.nextStep(step));
                }
                data.setKatanaStanceId(stanceParam);

                // P1-5 (3/3): подтверждение клиенту.
                sendKatanaComboSync(player, serverStep, data.getKatanaComboStep(), hitSomething,
                        hitSomething
                                ? com.example.shinobicore.combat.ComboMachine.RejectReason.OK
                                : com.example.shinobicore.combat.ComboMachine.RejectReason.WHIFF);
            });
        });
    }

    private static void registerKatanaStance() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.KATANA_STANCE_ID, (server, player, handler, buf, responseSender) -> {
            final String stanceId = PacketValidator.safeReadString(buf);
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setKatanaStanceId(stanceId));
        });
    }

    private static void registerKatanaDeflect() {
        ServerPlayNetworking.registerGlobalReceiver(ModPackets.KATANA_DEFLECT_ID, (server, player, handler, buf, responseSender) -> {
            final boolean held = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (KenjutsuStance.fromId(data.getKatanaStanceId()).canDeflect()) {
                    com.example.shinobicore.combat.CombatFeelServer.onDeflectToggle(player.getUuid(), held);
                data.setKatanaDeflectHeld(held);
                    if (!held) {
                        data.setKatanaDeflectUntil(System.currentTimeMillis() + 300);
                    }
                }
            });
        });
    }
}