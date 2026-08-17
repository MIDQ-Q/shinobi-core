package com.example.shinobicore.client;

import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.dojutsu.SharinganClientState;
import com.example.shinobicore.client.dojutsu.SharinganOverlayRenderer;
import com.example.shinobicore.client.sensory.SensoryClientState;
import com.example.shinobicore.client.sensory.SensoryHudRenderer;
import com.example.shinobicore.client.sensory.SensoryScanRenderer;
import com.example.shinobicore.client.sensory.SensoryReadingHud;
import com.example.shinobicore.client.ui.HudConfig;
import com.example.shinobicore.client.ui.HudWidgetManager;
import com.example.shinobicore.client.ui.widgets.ResourceBarWidget;
import com.example.shinobicore.client.ui.widgets.CastBarWidget;
import com.example.shinobicore.client.ui.widgets.StatusIconWidget;
import com.example.shinobicore.client.RasenganClientVisual;
import com.example.shinobicore.client.render.ShaderCompatibilityManager;
import com.example.shinobicore.client.vfx.VoxelPerformanceOptimizer;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import com.example.shinobicore.client.combat.TaijutsuSounds;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.entity.NinjaProjectileRenderer;
import com.example.shinobicore.entity.ShurikenRenderer;
import com.example.shinobicore.network.ChakraSyncPacket;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.StatType;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.BuiltinItemRendererRegistry;
// import not needed - using static method reference
import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import com.example.shinobicore.client.CinematicCamera;
import com.example.shinobicore.client.HandSignsClientState;
import com.example.shinobicore.client.HandSignsHudRenderer;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.AttributeSyncPacket;
import com.example.shinobicore.network.S06NetworkLayer;
import com.example.shinobicore.network.NetworkDebugLogger;
import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.combat.HitStopManager;
import com.example.shinobicore.client.render.NarutoArmorRenderer;
import com.example.shinobicore.client.render.BackKatanaRenderer;
import net.fabricmc.fabric.api.client.rendering.v1.LivingEntityFeatureRendererRegistrationCallback;
import net.minecraft.entity.EntityType;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
public class ShinobiCoreClient implements ClientModInitializer {

    @Override
    public void onInitializeClient() {
        KeyBindings.register();
        // S5-07: Initialize shader compatibility detection
        ShaderCompatibilityManager.init();
        // S4-09: Load voxel quality settings
        com.example.shinobicore.client.vfx.VoxelQualityConfig.load();

        // S3-01: Load HUD config and register UI widgets
        HudWidgetManager.register(new ResourceBarWidget());
        HudWidgetManager.register(new CastBarWidget());
        HudWidgetManager.register(new StatusIconWidget());
        ShinobiCore.LOGGER.info("[UI] S3 widgets registered");
        ClientInputHandler.register();
        ChakraPhysicsClient.register();
        ParkourManager.register();
        TaijutsuClientHandler.register();
        RasenganClientVisual.register();
        RasenshurikenClientVisual.register();
        com.example.shinobicore.client.ChakraAuraVisual.register();
        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
        CastBarHudRenderer.register(); // S3-03
        StatusIconsRenderer.register(); // S3-04
        HudSettings.load(); // S3-05
        HudRenderCallback.EVENT.register(HudWidgetManager::render);
        com.example.shinobicore.client.TargetFrameHud.register();
        com.example.shinobicore.client.RpgCameraKeybind.register(); // PHASE_H_CAMERA // BATCH3_AURA
        com.example.shinobicore.client.LandingAnimations.register();
        com.example.shinobicore.client.LandingControlRecovery.register(); // S2-08 // PHASE_A_REG
        // === РЕГИСТРАЦИЯ РЕНДЕРЕРОВ (было потеряно!) ===
        EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);
        EntityRendererRegistry.register(ModEntities.SHURIKEN, ShurikenRenderer::new);
        EntityRendererRegistry.register(ModEntities.VOXEL_PROJECTILE, com.example.shinobicore.entity.VoxelProjectileRenderer::new);
        EntityRendererRegistry.register(ModEntities.RASENSHURIKEN, com.example.shinobicore.entity.RasenshurikenRenderer::new);
        EntityRendererRegistry.register(ModEntities.RASENGAN_HAND, com.example.shinobicore.entity.RasenganHandRenderer::new);
        EntityRendererRegistry.register(ModEntities.DRAGON, com.example.shinobicore.entity.DragonRenderer::new);
        // S5-05: Register custom particle system
        com.example.shinobicore.client.vfx.particles.VoxelParticleRenderer.register();
        EntityRendererRegistry.register(ModEntities.DOT_ZONE, com.example.shinobicore.entity.DotZoneRenderer::new);
        // PHASE_K3_KATANA_RENDERER_REGISTERED
        BuiltinItemRendererRegistry.INSTANCE.register(com.example.shinobicore.item.ModItems.KATANA, com.example.shinobicore.client.render.KatanaBuiltinRenderer::render);
        
        // === РЕГИСТРАЦИЯ ЗВУКОВ ===
        Registry.register(Registries.SOUND_EVENT, TaijutsuSounds.PUNCH_LIGHT.getId(), TaijutsuSounds.PUNCH_LIGHT);
        Registry.register(Registries.SOUND_EVENT, TaijutsuSounds.PUNCH_HEAVY.getId(), TaijutsuSounds.PUNCH_HEAVY);
        Registry.register(Registries.SOUND_EVENT, TaijutsuSounds.KICK.getId(), TaijutsuSounds.KICK);
        Registry.register(Registries.SOUND_EVENT, TaijutsuSounds.WHOOSH.getId(), TaijutsuSounds.WHOOSH);
        TaijutsuSounds.setCustomSoundsRegistered(true);
        ShinobiCore.LOGGER.info("Registered taijutsu sounds");

        // === РЕГИСТРАЦИЯ КИНЕМАТОГРАФИЧНОЙ КАМЕРЫ ===
        ClientTickEvents.END_CLIENT_TICK.register(CinematicCamera::tick);
        // S5-08: Reset performance counters each frame
        ClientTickEvents.END_CLIENT_TICK.register(client -> VoxelPerformanceOptimizer.resetFrame());
        ClientTickEvents.END_CLIENT_TICK.register(HudWidgetManager::tick);
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (client.player != null) {
                com.example.shinobicore.client.prediction.ClientPredictionManager.tick(client.player);
            }
        });
        ShinobiCore.LOGGER.info("Registered cinematic camera");

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CHAKRA_SYNC_ID, (client, handler, buf, responseSender) -> {
            ChakraSyncPacket packet = ChakraSyncPacket.read(buf);
            client.execute(() -> {
                ChakraHudRenderer.currentChakra = packet.currentChakra();
                ChakraHudRenderer.maxChakra = packet.maxChakra();
                ChakraHudRenderer.currentStamina = packet.currentStamina();
                ChakraHudRenderer.maxStamina = packet.maxStamina();
                ChakraHudRenderer.fatigue = packet.fatigue();
                ChakraHudRenderer.currentStamina = packet.currentStamina();
                ChakraHudRenderer.maxStamina = packet.maxStamina();
                ChakraHudRenderer.exhausted = packet.exhausted();
                ClientNinjaState.meditating = packet.meditating();
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CATALOG_SYNC_ID, (client, handler, buf, responseSender) -> {
            Map<String, String> cat = new HashMap<>();
            int n = buf.readInt();
            for (int i = 0; i < n; i++) cat.put(buf.readString(), buf.readString());
            client.execute(() -> {
                ClientNinjaState.catalog.clear();
                ClientNinjaState.catalog.putAll(cat);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.LOADOUT_SYNC_ID, (client, handler, buf, responseSender) -> {
            int aA = buf.readInt(); int aB = buf.readInt();
            String[] la = new String[5]; String[] lb = new String[5];
            for (int i = 0; i < 5; i++) { String s = buf.readString(); la[i] = s.isEmpty() ? null : s; }
            for (int i = 0; i < 5; i++) { String s = buf.readString(); lb[i] = s.isEmpty() ? null : s; }
            Set<String> learned = new HashSet<>();
            int lc = buf.readInt();
            for (int i = 0; i < lc; i++) learned.add(buf.readString());
            client.execute(() -> {
                ClientNinjaState.activeA = aA; ClientNinjaState.activeB = aB;
                for (int i = 0; i < 5; i++) { ClientNinjaState.loadoutA[i] = la[i]; ClientNinjaState.loadoutB[i] = lb[i]; }
                ClientNinjaState.learned.clear();
                ClientNinjaState.learned.addAll(learned);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.RASENGAN_SYNC_ID, (client, handler, buf, responseSender) -> {
            boolean charging = buf.readBoolean();
            float progress = buf.readFloat();
            boolean ready = buf.readBoolean();
            client.execute(() -> {
                RasenganClientState.charging = charging;
                RasenganClientState.chargeProgress = progress;
                RasenganClientState.ready = ready;
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.STATS_SYNC_ID, (client, handler, buf, responseSender) -> {
            int sp = buf.readInt(); int resLvl = buf.readInt(); int resXp = buf.readInt();
            Map<String, Integer> sl = new HashMap<>(); Map<String, Integer> sx = new HashMap<>();
            for (StatType s : StatType.values()) { sl.put(s.getId(), buf.readInt()); sx.put(s.getId(), buf.readInt()); }
            Map<String, Integer> nl = new HashMap<>(); Map<String, Integer> nx = new HashMap<>(); Map<String, Boolean> nu = new HashMap<>();
            for (ElementType e : ElementType.values()) { nl.put(e.getId(), buf.readInt()); nx.put(e.getId(), buf.readInt()); }
            for (ElementType e : ElementType.values()) nu.put(e.getId(), buf.readBoolean());
        boolean sen = buf.readBoolean();
            client.execute(() -> {
                ClientNinjaState.skillPoints = sp;
                ClientNinjaState.reserveLevel = resLvl;
                ClientNinjaState.reserveXp = resXp;
                ClientNinjaState.statLevels.clear(); ClientNinjaState.statLevels.putAll(sl);
                ClientNinjaState.statXp.clear(); ClientNinjaState.statXp.putAll(sx);
                ClientNinjaState.natureLevels.clear(); ClientNinjaState.natureLevels.putAll(nl);
                ClientNinjaState.natureXp.clear(); ClientNinjaState.natureXp.putAll(nx);
                ClientNinjaState.natureUnlocked.clear(); ClientNinjaState.natureUnlocked.putAll(nu);
                ClientNinjaState.sensoryEnabled = sen;
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(new net.minecraft.util.Identifier("shinobicore", "rs_sync"), (client, handler, buf, responseSender) -> {
                boolean charging = buf.readBoolean();
                float progress = buf.readFloat();
                boolean ready = buf.readBoolean();
                client.execute(() -> {
                    RasenshurikenClientState.charging = charging;
                    RasenshurikenClientState.progress = progress;
                    RasenshurikenClientState.ready = ready;
            });
        });
        
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.BODY_SYNC_ID, (client, handler, buf, responseSender) -> {
            int hp = buf.readInt(); int speed = buf.readInt(); int jump = buf.readInt();
            boolean chakra = buf.readBoolean(); String clan = buf.readString(); String affinity = buf.readString();
            client.execute(() -> {
                ClientNinjaState.hpLevel = hp;
                ClientNinjaState.speedLevel = speed;
                ClientNinjaState.jumpLevel = jump;
                ClientNinjaState.chakraMode = chakra;
                ClientNinjaState.clanId = clan.isEmpty() ? "none" : clan;
                ClientNinjaState.affinityId = affinity.isEmpty() ? null : affinity;
                if (buf.readableBytes() > 0) {
                    String dojutsu = buf.readString();
                    ClientNinjaState.activeDojutsu = dojutsu.isEmpty() ? null : dojutsu;
                }
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.TREE_SYNC_ID, (client, handler, buf, responseSender) -> {
            int count = buf.readInt();
            Set<String> nodes = new HashSet<>();
            for (int i = 0; i < count; i++) nodes.add(buf.readString());
            // S1-07: Read teacher approved nodes
            int teacherCount = buf.readInt();
            Set<String> teacherNodes = new HashSet<>();
            for (int i = 0; i < teacherCount; i++) teacherNodes.add(buf.readString());
            client.execute(() -> {
                ClientNinjaState.unlockedNodes.clear();
                ClientNinjaState.unlockedNodes.addAll(nodes);
                ClientNinjaState.teacherApproved.clear();
                ClientNinjaState.teacherApproved.addAll(teacherNodes);
            });
        });

        // S6-03: Direction sense receiver
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SENSORY_DIRECTION_ID, (client, handler, buf, responseSender) -> {
            boolean active = buf.readBoolean();
            float dirX = buf.readFloat();
            float dirZ = buf.readFloat();
            client.execute(() -> {
                SensoryClientState.directionActive = active;
                SensoryClientState.directionX = dirX;
                SensoryClientState.directionZ = dirZ;
            });
        });
        // S6-04: Scan results receiver
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SENSORY_SCAN_ID, (client, handler, buf, responseSender) -> {
            int count = buf.readInt();
            java.util.List<SensoryClientState.ScanEntity> entities = new java.util.ArrayList<>();
            for (int i = 0; i < count; i++) {
                int eid = buf.readInt();
                double x = buf.readDouble();
                double y = buf.readDouble();
                double z = buf.readDouble();
                float height = buf.readFloat();
                boolean hostile = buf.readBoolean();
                entities.add(new SensoryClientState.ScanEntity(eid, x, y, z, height, hostile));
            }
            client.execute(() -> {
                SensoryClientState.scanEntities = entities;
                SensoryClientState.scanTimestamp = System.currentTimeMillis();
            });
        });
        // S6-06: Chakra reading receiver
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SENSORY_READING_ID, (client, handler, buf, responseSender) -> {
            int eid = buf.readInt();
            String name = buf.readString();
            float chakraRatio = buf.readFloat();
            boolean chakraMode = buf.readBoolean();
            int reserve = buf.readInt();
            boolean hasDojutsu = buf.readBoolean();
            String dojutsuId = buf.readString();
            client.execute(() -> {
                SensoryClientState.lastReading = new SensoryClientState.ReadingData(
                    eid, name, chakraRatio, chakraMode, reserve, hasDojutsu, dojutsuId);
                SensoryClientState.readingTimestamp = System.currentTimeMillis();
            });
        });
        // Sharingan sync receiver
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.SHARINGAN_SYNC_ID, (client, handler, buf, responseSender) -> {
            int stage = buf.readInt();
            boolean active = buf.readBoolean();
            int usage = buf.readInt();
            int stress = buf.readInt();
            client.execute(() -> {
                SharinganClientState.stageLevel = stage;
                SharinganClientState.active = active;
                SharinganClientState.usageProgress = usage;
                SharinganClientState.stressCount = stress;
            });
        });
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID, (client, handler, buf, responseSender) -> {
            boolean danger = buf.readBoolean();
            client.execute(() -> ClientNinjaState.dangerSense = danger);
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CAST_FX_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            String nature = buf.readString();
            client.execute(() -> {
                if (client.world != null && client.world.getEntityById(entityId) instanceof AbstractClientPlayerEntity p) {
                    CastingClientState.startCast(p.getUuid(), nature);
                }
            });
        });
        CastingClientVisual.register();
        com.example.shinobicore.client.combat.SwordTrailRenderer.register(); // PHASE_K1_TRAIL_REGISTERED
        ChakraAuraRenderer.register(); // PHASE_E_AURA_REGISTERED
                ClientPlayNetworking.registerGlobalReceiver(com.example.shinobicore.network.PredictionCorrectionPacket.ID, (client, handler, buf, responseSender) -> {
            final com.example.shinobicore.network.PredictionCorrectionPacket packet = com.example.shinobicore.network.PredictionCorrectionPacket.read(buf);
            client.execute(() -> {
                if (client.player != null) {
                    com.example.shinobicore.client.prediction.ClientPredictionManager.applyCorrection(client.player, packet.getPos(), packet.getVel());
                }
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.HIT_STOP_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            int durationMs = buf.readInt();
            client.execute(() -> HitStopManager.freeze(entityId, durationMs));
        });
        ClientPlayConnectionEvents.DISCONNECT.register((handler, client) -> {
            IdlePoseSystem.cleanupAll();
            com.example.shinobicore.client.LandingControlRecovery.cleanupAll(); // S2-08
            com.example.shinobicore.client.combat.TaijutsuAnimations.cleanup(client.player.getUuid());
            com.example.shinobicore.client.combat.KenjutsuAnimations.cleanup(client.player.getUuid());
            CastingClientState.clear();
            HitStopManager.clear();
            HandSignsClientState.clear();
        SharinganClientState.clear();
        SensoryClientState.clear();
        com.example.shinobicore.client.vfx.particles.VoxelParticleManager.clear();
        });
                        // === PHASE5 HAND SIGNS ===
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CAST_START_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            String jutsuId = buf.readString();
            int durationTicks = buf.readInt();
            client.execute(() -> HandSignsClientState.startCasting(entityId, jutsuId, durationTicks));
        });
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CAST_INTERRUPT_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            client.execute(() -> HandSignsClientState.interruptCasting(entityId));
        });
        HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);
        HudRenderCallback.EVENT.register(com.example.shinobicore.client.debug.DebugOverlayRenderer::render);

        // === S0-01: Attribute delta sync receiver ===
        ClientPlayNetworking.registerGlobalReceiver(AttributeSyncPacket.ID, (client, handler, buf, responseSender) -> {
            final AttributeSyncPacket packet = AttributeSyncPacket.read(buf);
            client.execute(() -> {
                if (client.player != null) {
                    ShinobiCore.LOGGER.debug("[ATTR-SYNC] Received {} attribute changes", packet.changedAttributes().size());
                }
            });
        });

        NarutoArmorRenderer.register();
        // Sharingan overlay renderer
        SharinganOverlayRenderer.register();
        // S6: Sensory system renderers
        SensoryHudRenderer.register();
        SensoryScanRenderer.register();
        SensoryReadingHud.register();
        LivingEntityFeatureRendererRegistrationCallback.EVENT.register((entityType, entityRenderer, registrationHelper, context) -> {
            if (entityRenderer instanceof net.minecraft.client.render.entity.PlayerEntityRenderer playerRenderer) {
                registrationHelper.register(new BackKatanaRenderer(playerRenderer));
            }
        });

        // === S0-06: Network Layer Receivers ===
        registerS06ClientReceivers();
    }

    // === S0-06: Client receivers for new packets ===
    private void registerS06ClientReceivers() {
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.VFX_SPAWN_ID, (client, handler, buf, responseSender) -> {
            int vfxType = buf.readByte() & 0xFF;
            double x = buf.readDouble(); double y = buf.readDouble(); double z = buf.readDouble();
            float scale = buf.readFloat();
            client.execute(() -> NetworkDebugLogger.logPacket("vfx_spawn", "S2C", client.player != null ? client.player.getName().getString() : "?", "type=" + vfxType));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.HIT_RESULT_ID, (client, handler, buf, responseSender) -> {
            int attackerId = buf.readVarInt(); int targetId = buf.readVarInt();
            float damage = buf.readFloat(); boolean crit = buf.readBoolean();
            client.execute(() -> NetworkDebugLogger.logPacket("hit_result", "S2C", client.player != null ? client.player.getName().getString() : "?", "dmg=" + damage + " crit=" + crit));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.DOJUTSU_STATE_ID, (client, handler, buf, responseSender) -> {
            String dojutsuId = buf.readString(); int stage = buf.readByte(); boolean active = buf.readBoolean();
            client.execute(() -> {
                NetworkDebugLogger.logPacket("dojutsu_state", "S2C", client.player != null ? client.player.getName().getString() : "?", "id=" + dojutsuId + " stage=" + stage);
                ClientNinjaState.activeDojutsu = dojutsuId.isEmpty() ? null : dojutsuId;
            });
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.KAWARIMI_FX_ID, (client, handler, buf, responseSender) -> {
            double x = buf.readDouble(); double y = buf.readDouble(); double z = buf.readDouble();
            client.execute(() -> NetworkDebugLogger.logPacket("kawarimi_fx", "S2C", client.player != null ? client.player.getName().getString() : "?"));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CLONE_SPAWN_ID, (client, handler, buf, responseSender) -> {
            int ownerId = buf.readVarInt(); int cloneId = buf.readVarInt();
            double x = buf.readDouble(); double y = buf.readDouble(); double z = buf.readDouble();
            client.execute(() -> NetworkDebugLogger.logPacket("clone_spawn", "S2C", client.player != null ? client.player.getName().getString() : "?", "clone=" + cloneId));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CLONE_DESPAWN_ID, (client, handler, buf, responseSender) -> {
            int cloneId = buf.readVarInt();
            client.execute(() -> NetworkDebugLogger.logPacket("clone_despawn", "S2C", client.player != null ? client.player.getName().getString() : "?", "clone=" + cloneId));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.CAST_COMPLETE_ID, (client, handler, buf, responseSender) -> {
            String jutsuId = buf.readString();
            client.execute(() -> NetworkDebugLogger.logPacket("cast_complete", "S2C", client.player != null ? client.player.getName().getString() : "?", "jutsu=" + jutsuId));
        });
        ClientPlayNetworking.registerGlobalReceiver(S06NetworkLayer.SENSORY_STATE_ID, (client, handler, buf, responseSender) -> {
            int tier = buf.readByte(); int radius = buf.readVarInt(); boolean active = buf.readBoolean();
            client.execute(() -> NetworkDebugLogger.logPacket("sensory_state", "S2C", client.player != null ? client.player.getName().getString() : "?", "tier=" + tier + " radius=" + radius));
        });
        
        ShinobiCore.LOGGER.info("[S0-06] Network layer client receivers registered");
    }
}