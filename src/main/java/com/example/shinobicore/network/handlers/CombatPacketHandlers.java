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
            if (!PacketRateLimiter.allow(player.getUuid(), "TAIJUTSU_ATTACK", 100)) return;
            if (!PacketValidator.validCombatState(player)) return;

            server.execute(() -> {
                if (player.getWorld().isClient()) return;
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                if (data.getCurrentChakra() <= 0) return;
                TaijutsuStyle style = TaijutsuStyle.fromId(styleId);
                int serverStep = data.getServerComboStep();
                if (clientComboStep != serverStep) {
                    ShinobiCore.LOGGER.warn("[ANTICHEAT] Player {} sent comboStep={}, expected={}",
                        player.getName().getString(), clientComboStep, serverStep);
                    return;
                }
                long now = System.currentTimeMillis();
                long lastAttack = data.getLastAttackTimeMs();
                int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
                int cooldownMs = TaijutsuFormulas.attackCooldownTicks(style, data.isChakraMode(), taijutsuLevel) * 50;
                if (now - lastAttack < cooldownMs - 50) return;
                long timeoutMs = (long)(TaijutsuCombo.COMBO_TIMEOUT_MS * (1 + TreePassives.collectServer(data).comboTimeoutBonus));
                if (now - lastAttack > timeoutMs && serverStep > 0) { data.resetCombo(); serverStep = 0; }
                boolean chakraMode = data.isChakraMode();
                float damage = TaijutsuFormulas.computeDamage(taijutsuLevel, style, chakraMode, serverStep, data.isExhausted());
                float knockback = TaijutsuCombo.getKnockback(serverStep);
                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = MeleeHitDetection.findTargetsInCone(
                    (ServerWorld) player.getWorld(), player, look);
                MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);
                for (LivingEntity t : targets) ShinobiCore.broadcastHitStop(player, t, 80, 160);
                data.setFatigue(data.getFatigue() + style.getFatiguePerHit());
                data.setLastAttackTimeMs(now);
                data.advanceComboStep();
                data.setCurrentStyleId(styleId);
            });
        });
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
            if (!PacketValidator.validCombatState(player)) return;

            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                KenjutsuStance stance = KenjutsuStance.fromId(stanceParam);
                long now = System.currentTimeMillis();
                int step = stepParam;
                if (data.isKatanaDeflectHeld()) return;
                if (step != data.getKatanaComboStep()) return;
                if (now - data.getKatanaLastAttackMs() < KenjutsuFormulas.cooldownMs(stance) - 50) return;
                if (now - data.getKatanaLastAttackMs() > 1500) { data.setKatanaComboStep(0); step = 0; }
                int tai = data.getStatLevel(StatType.TAIJUTSU);
                float damage = KenjutsuFormulas.computeDamage(tai, stance, data.isChakraMode(), step, data.isExhausted());
                if (stance == KenjutsuStance.IAI && now - data.getKatanaLastAttackMs() > 2000) {
                    damage *= 2.2f;
                    player.sendMessage(Text.literal("\u00a76IAI CRIT!"), false);
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
                for (LivingEntity t : targets) {
                    t.damage(player.getDamageSources().playerAttack(player), damage);
                    Vec3d kb = t.getPos().subtract(player.getPos()).normalize().multiply(KenjutsuFormulas.getKnockback(step));
                    t.addVelocity(kb.x, 0.2, kb.z);
                    t.velocityModified = true;
                }
                data.setFatigue(data.getFatigue() + 1.5f);
                data.setKatanaLastAttackMs(now);
                data.setKatanaComboStep((step + 1) % 4);
                data.setKatanaStanceId(stanceParam);
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
                    data.setKatanaDeflectHeld(held);
                    if (!held) {
                        data.setKatanaDeflectUntil(System.currentTimeMillis() + 300);
                    }
                }
            });
        });
    }
}