package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.MeleeHitDetection;
import com.example.shinobicore.combat.TaijutsuCombo;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.KenjutsuFormulas;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.KenjutsuFormulas;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.combat.TaijutsuCombo;
import com.example.shinobicore.combat.MeleeHitDetection;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.pose.LowPoseTracker;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.tree.TreePassives;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
public class ModPackets {
    public static final Identifier CHAKRA_SYNC_ID = new Identifier("shinobicore", "chakra_sync");
    public static final Identifier MEDITATE_ID = new Identifier("shinobicore", "meditate");
    public static final Identifier SELECT_SLOT_ID = new Identifier("shinobicore", "select_slot");
    public static final Identifier CAST_SLOT_ID = new Identifier("shinobicore", "cast_slot");
    public static final Identifier SET_SLOT_ID = new Identifier("shinobicore", "set_slot");
    public static final Identifier LOADOUT_SYNC_ID = new Identifier("shinobicore", "loadout_sync");
    public static final Identifier CATALOG_SYNC_ID = new Identifier("shinobicore", "catalog_sync");
    public static final Identifier STATS_SYNC_ID = new Identifier("shinobicore", "stats_sync");
    public static final Identifier SPEND_SP_ID = new Identifier("shinobicore", "spend_sp");
    public static final Identifier BODY_SYNC_ID = new Identifier("shinobicore", "body_sync");
    public static final Identifier CHAKRA_MODE_ID = new Identifier("shinobicore", "chakra_mode");
    public static final Identifier PARKOUR_ACTION_ID = new Identifier("shinobicore", "parkour_action");
    public static final Identifier DODGE_ID = new Identifier("shinobicore", "dodge");
    public static final Identifier POSE_SYNC_ID = new Identifier("shinobicore", "pose_sync");
    public static final Identifier TAIJUTSU_ATTACK_ID = new Identifier("shinobicore", "taijutsu_attack");
    public static final Identifier TAIJUTSU_KICK_ID = new Identifier("shinobicore", "taijutsu_kick");
    public static final Identifier TAIJUTSU_STYLE_ID = new Identifier("shinobicore", "taijutsu_style");
    public static final Identifier RASENGAN_SYNC_ID = new Identifier("shinobicore", "rasengan_sync");
    public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");
    public static final Identifier KATANA_ATTACK_ID = new Identifier("shinobicore", "katana_attack");
    public static final Identifier KATANA_STANCE_ID = new Identifier("shinobicore", "katana_stance");
    public static final Identifier KATANA_DEFLECT_ID = new Identifier("shinobicore", "katana_deflect");
    public static final Identifier CAST_FX_ID = new Identifier("shinobicore", "cast_fx");
    public static final Identifier ATTUNEMENT_ID = new Identifier("shinobicore", "attunement");
    public static final Identifier TREE_SYNC_ID = new Identifier("shinobicore", "tree_sync");
    public static final Identifier UNLOCK_NODE_ID = new Identifier("shinobicore", "unlock_node");
    public static final Identifier CONTROL_TRAIN_ID = new Identifier("shinobicore", "control_train");
    public static final Identifier DANGER_SYNC_ID = new Identifier("shinobicore", "danger_sync");
    public static final Identifier SENSORY_TOGGLE_ID = new Identifier("shinobicore", "sensory_toggle");
    public static final Identifier CAST_START_ID = new Identifier("shinobicore", "cast_start");
    public static final Identifier CAST_INTERRUPT_ID = new Identifier("shinobicore", "cast_interrupt");
    public static final Identifier HIT_STOP_ID = new Identifier("shinobicore", "hit_stop");
    
    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(MEDITATE_ID, (server, player, handler, buf, responseSender) -> {
            boolean start = buf.readBoolean();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setMeditating(start));
        });

        // === РАСЕНГАН: удар (клиент → сервер) ===
        ServerPlayNetworking.registerGlobalReceiver(RASENGAN_STRIKE_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                ShinobiCore.handleRasenganStrike(player);
            });
        });

        // === РђРўРўР®РќРњР•РќРў (РєР»РёРµРЅС‚ -> СЃРµСЂРІРµСЂ) ===
        ServerPlayNetworking.registerGlobalReceiver(ATTUNEMENT_ID, (server, player, handler, buf, responseSender) -> {
            String elementId = buf.readString();
            boolean success = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                ElementType element = null;
                for (ElementType e : ElementType.values()) {
                    if (e.getId().equals(elementId)) { element = e; break; }
                }
                if (element == null) return;

                if (success) {
                    int unlockedCount = 0;
                    for (ElementType e2 : ElementType.values()) {
                        if (data.isNatureUnlocked(e2)) unlockedCount++;
                    }
                    int cost = 10 + unlockedCount * 5;
                    if (data.getSkillPoints() < cost) {
                        player.sendMessage(Text.literal("В§cNot enough SP! Need " + cost), false);
                        return;
                    }
                    data.addSkillPoints(-cost);
                    data.setNatureUnlocked(element, true);
                    if (data.getNatureLevel(element) < 1) {
                        data.setNatureLevel(element, 1);
                    }
                    ShinobiCore.sendStatsSync(player);
                    player.sendMessage(Text.literal("В§aAttuned to " + elementId + "! (-" + cost + " SP)"), false);
                } else {
                    player.sendMessage(Text.literal("В§cAttunement failed."), false);
                }
            });
        });

        // === Р”Р Р•Р’Рћ: СЂР°Р·Р±Р»РѕРєРёСЂРѕРІРєР° СѓР·Р»Р° (РєР»РёРµРЅС‚ -> СЃРµСЂРІРµСЂ) ===
        ServerPlayNetworking.registerGlobalReceiver(CONTROL_TRAIN_ID, (server, player, handler, buf, responseSender) -> {
            boolean success = buf.readBoolean();
            float accuracy = buf.readFloat();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                int xp = success ? Math.round(15 + accuracy * 25) : 3;
                NinjaFormula.grantStatXp(data, StatType.CONTROL, xp);
                ShinobiCore.sendStatsSync(player);
                player.sendMessage(Text.literal(success
                    ? String.format("В§aControl training: +%d XP (%.0f%%)", xp, accuracy * 100)
                    : "В§7Training: +" + xp + " XP"), false);
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(UNLOCK_NODE_ID, (server, player, handler, buf, responseSender) -> {
            String nodeId = buf.readString();
            server.execute(() -> ShinobiCore.handleUnlockNode(player, nodeId));
        });

        ServerPlayNetworking.registerGlobalReceiver(SELECT_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt(); int slot = buf.readInt();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setActiveSlot(set, slot));
        });

        ServerPlayNetworking.registerGlobalReceiver(CAST_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt(); 
            int slot = buf.readInt();
            
            ShinobiCore.LOGGER.info("[CAST-SERVER] === RECEIVED PACKET ===");
            ShinobiCore.LOGGER.info("[CAST-SERVER] Player: {}", player.getName().getString());
            ShinobiCore.LOGGER.info("[CAST-SERVER] Set: {}, Slot: {}", set, slot);
            
            server.execute(() -> {
                ShinobiCore.LOGGER.info("[CAST-SERVER] Processing on server thread...");
                
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data == null) {
                    ShinobiCore.LOGGER.info("[CAST-SERVER] ✗ NinjaPlayerData is null");
                    return;
                }
                
                int s = Math.max(0, Math.min(4, slot));
                String id = data.getLoadoutSlot(set == 0 ? 0 : 1, s);
                
                ShinobiCore.LOGGER.info("[CAST-SERVER] Loadout slot lookup: set={}, slot={} → id={}", 
                    set == 0 ? 0 : 1, s, id);
                
                if (id != null) {
                    ShinobiCore.LOGGER.info("[CAST-SERVER] ✓ Calling JutsuCaster.cast(player, {})", id);
                    boolean success = JutsuCaster.beginCast(player, id); // === PHASE5_USE_BEGINCAST ===
                    ShinobiCore.LOGGER.info("[CAST-SERVER] JutsuCaster.cast returned: {}", success);
                } else {
                    ShinobiCore.LOGGER.info("[CAST-SERVER] ✗ Slot {} is empty!", s + 1);
                    player.sendMessage(Text.literal("§cSlot " + (s + 1) + " is empty!"), false);
                }
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(TAIJUTSU_ATTACK_ID, (server, player, handler, buf, responseSender) -> {
            // === ИСПРАВЛЕНО: серверная валидация комбо (анти-чит) ===
            int clientComboStep = buf.readInt();
            String styleId = buf.readString();

            server.execute(() -> {
                if (player.getWorld().isClient()) return;
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                if (data.getCurrentChakra() <= 0) return;

                // === ВАЛИДАЦИЯ: проверяем что стиль валиден ===
                TaijutsuStyle style = TaijutsuStyle.fromId(styleId);
                
                // === ВАЛИДАЦИЯ: проверяем что comboStep совпадает с серверным ===
                int serverStep = data.getServerComboStep();
                if (clientComboStep != serverStep) {
                    ShinobiCore.LOGGER.warn("[ANTICHEAT] Player {} sent comboStep={}, expected={}",
                            player.getName().getString(), clientComboStep, serverStep);
                    return; // Отклоняем
                }

                // === ВАЛИДАЦИЯ: проверяем кулдаун между ударами ===
                long now = System.currentTimeMillis();
                                        long lastAttack = data.getLastAttackTimeMs();
            int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);

                int cooldownMs = TaijutsuFormulas.attackCooldownTicks(style, data.isChakraMode(), taijutsuLevel) * 50; // PHASE7_ANTICHEAT
                
                // Разрешаем небольшой допуск (50мс) для пинга
                if (now - lastAttack < cooldownMs - 50) {
                    ShinobiCore.LOGGER.warn("[ANTICHEAT] Player {} attacked too fast: {}ms since last (cooldown={}ms)",
                            player.getName().getString(), now - lastAttack, cooldownMs);
                    return; // Отклоняем
                }

                // === ВАЛИДАЦИЯ: сбрасываем комбо если прошло слишком много времени ===
                long timeoutMs = (long)(TaijutsuCombo.COMBO_TIMEOUT_MS * (1 + TreePassives.collectServer(data).comboTimeoutBonus));
                if (now - lastAttack > timeoutMs && serverStep > 0) {
                    data.resetCombo();
                    serverStep = 0;
                }

                // Всё ок — применяем урон
                boolean chakraMode = data.isChakraMode();
                float damage = TaijutsuFormulas.computeDamage(taijutsuLevel, style, chakraMode, serverStep, data.isExhausted());
                float knockback = TaijutsuCombo.getKnockback(serverStep);
                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = MeleeHitDetection.findTargetsInCone(
                        (ServerWorld) player.getWorld(), player, look);
                MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);
                // === HITSTOP_TAIJUTSU ===
                for (LivingEntity t : targets) {
                    ShinobiCore.broadcastHitStop(player, t, 80, 160);
                }
                data.setFatigue(data.getFatigue() + style.getFatiguePerHit());

                // Обновляем серверное состояние
                data.setLastAttackTimeMs(now);
                data.advanceComboStep();
                data.setCurrentStyleId(styleId);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(TAIJUTSU_STYLE_ID, (server, player, handler, buf, responseSender) -> {
            String newStyleId = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                TaijutsuStyle style = TaijutsuStyle.fromId(newStyleId);
                
                // Проверяем разблокировку Strong Fist
                int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
                if (style == TaijutsuStyle.STRONG_FIST && !TaijutsuFormulas.canUseStrongFist(taijutsuLevel)) {
                    player.sendMessage(Text.literal("§cYou need Taijutsu level " + 
                            TaijutsuFormulas.strongFistUnlockLevel() + " to use Strong Fist!"), false);
                    return;
                }
                
                data.setCurrentStyleId(newStyleId);
                ShinobiCore.sendBodySync(player);
                player.sendMessage(Text.literal("§aStyle changed to: " + style.getId()), false);
            });
        });

        
        ServerPlayNetworking.registerGlobalReceiver(TAIJUTSU_KICK_ID, (server, player, handler, buf, responseSender) -> {
            String styleId = buf.readString();
            server.execute(() -> {
                if (player.getWorld().isClient()) return;
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;

                TaijutsuStyle style = TaijutsuStyle.fromId(styleId);
            int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
                boolean chakraMode = data.isChakraMode();

                // Удар ногой = x1.5 урона обычного удара
                float baseDamage = TaijutsuFormulas.computeDamage(taijutsuLevel, style, chakraMode, 2, data.isExhausted());
                float damage = baseDamage * 1.5f;
                float knockback = 1.5f;

                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = MeleeHitDetection.findTargetsInCone(
                    (ServerWorld) player.getWorld(), player, look);
                MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);
                // === HITSTOP_TAIJUTSU ===
                for (LivingEntity t : targets) {
                    ShinobiCore.broadcastHitStop(player, t, 80, 160);
                }

                data.setFatigue(data.getFatigue() + style.getFatiguePerHit() * 1.5f);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(SENSORY_TOGGLE_ID, (server, player, handler, buf, responseSender) -> {
            boolean enabled = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setSensoryEnabled(enabled);
                ShinobiCore.sendStatsSync(player);
            });
        });
        
        ServerPlayNetworking.registerGlobalReceiver(KATANA_ATTACK_ID, (server, player, handler, buf, responseSender) -> {
            final int stepParam = buf.readInt();
            final String stanceParam = buf.readString();
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
        sw3.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(), 20, 0.5, 0.5, 0.5, 0.1);
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
        ServerPlayNetworking.registerGlobalReceiver(KATANA_STANCE_ID, (server, player, handler, buf, responseSender) -> {
            String stanceId = buf.readString();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setKatanaStanceId(stanceId));
        });
        ServerPlayNetworking.registerGlobalReceiver(KATANA_DEFLECT_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (KenjutsuStance.fromId(data.getKatanaStanceId()).canDeflect()) {
                    data.setKatanaDeflectUntil(System.currentTimeMillis() + 300);
                }
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(DODGE_ID, (server, player, handler, buf, responseSender) -> {
            int direction = buf.readInt(); // -1 = влево, 1 = вправо
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.getCurrentChakra() <= 0 || data.isExhausted()) return;
                
                // Усталость за dodge
                data.setFatigue(data.getFatigue() + ModConfig.instance.parkour.dodgeFatigue);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(POSE_SYNC_ID, (server, player, handler, buf, responseSender) -> {
            boolean low = buf.readBoolean();
            server.execute(() -> LowPoseTracker.set(player.getUuid(), low));
        });

        ServerPlayConnectionEvents.DISCONNECT.register((handler, server) ->
            LowPoseTracker.set(handler.player.getUuid(), false));

        ServerPlayNetworking.registerGlobalReceiver(SET_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt(); int slot = buf.readInt(); String id = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                String clean = id.isEmpty() ? null : id;
                if (clean != null && !data.getLearnedJutsus().contains(clean)) {
                    player.sendMessage(Text.literal("§cLearn it first!"), false);
                    return;
                }
                data.setLoadoutSlot(set, Math.max(0, Math.min(4, slot)), clean);
                ShinobiCore.sendLoadoutSync(player);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(SPEND_SP_ID, (server, player, handler, buf, responseSender) -> {
            String type = buf.readString(); String id = buf.readString();
            server.execute(() -> ShinobiCore.handleSpendSp(player, type, id));
        });

        ServerPlayNetworking.registerGlobalReceiver(CHAKRA_MODE_ID, (server, player, handler, buf, responseSender) -> {
            boolean enable = buf.readBoolean();
            ShinobiCore.LOGGER.info("[CHAKRA-SERVER] Packet received: player={}, enable={}", 
                player.getName().getString(), enable);
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setChakraMode(enable);
                ShinobiCore.LOGGER.info("[CHAKRA-SERVER] Server chakraMode set to: {}", enable);
                ShinobiCore.sendBodySync(player);
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(PARKOUR_ACTION_ID, (server, player, handler, buf, responseSender) -> {
            // === ИСПРАВЛЕНО: читаем ВСЕ данные ИЗ буфера СРАЗУ, ДО server.execute() ===
            String actionId = buf.readString();
            float fatigueValue = 0;
            if (actionId.equals("charged_jump")) {
                fatigueValue = buf.readFloat();
            }
            // Копируем значение в final переменную для использования в server.execute()
            final float finalFatigue = fatigueValue;
            final String finalActionId = actionId;

            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.getCurrentChakra() <= 0 || data.isExhausted()) return;
                float f = 0;
                if (finalActionId.equals("charged_jump")) {
                    f = finalFatigue;
                } else {
                    switch (finalActionId) {
                        case "slide": f = ModConfig.instance.parkour.slideFatigue; break;
                        case "double_jump": f = ModConfig.instance.parkour.doubleJumpFatigue; break;
                        case "wall_jump": f = ModConfig.instance.parkour.wallJumpFatigue; break;
                        case "vault": f = ModConfig.instance.parkour.vaultFatigue; break;
                        case "wall_run": f = ModConfig.instance.parkour.wallRunFatiguePerTick; break;
                        case "edge_grab": f = ModConfig.instance.parkour.edgeGrabFatigue; break;
                        case "roll": f = ModConfig.instance.parkour.rollFatigue; break;
                    }
                }
                if (f > 0) data.setFatigue(data.getFatigue() + f);
            });
        });

        // === HIT-STOP (server -> client): freeze-frame on hit ===
        // This is S2C only, no server receiver needed.
        // Server sends it via ShinobiCore.broadcastHitStop()
    }
}