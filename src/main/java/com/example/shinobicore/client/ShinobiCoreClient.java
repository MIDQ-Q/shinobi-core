package com.example.shinobicore.client;

import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.RasenganClientVisual;
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
import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.combat.HitStopManager;
public class ShinobiCoreClient implements ClientModInitializer {

    @Override
    public void onInitializeClient() {
        KeyBindings.register();
        ClientInputHandler.register();
        ChakraPhysicsClient.register();
        ParkourManager.register();
        TaijutsuClientHandler.register();
        RasenganClientVisual.register();
        RasenshurikenClientVisual.register();
        com.example.shinobicore.client.ChakraAuraVisual.register();
        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
        com.example.shinobicore.client.TargetFrameHud.register();
        com.example.shinobicore.client.RpgCameraKeybind.register(); // PHASE_H_CAMERA // BATCH3_AURA
        com.example.shinobicore.client.LandingAnimations.register(); // PHASE_A_REG
        // === РЕГИСТРАЦИЯ РЕНДЕРЕРОВ (было потеряно!) ===
        EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);
        EntityRendererRegistry.register(ModEntities.SHURIKEN, ShurikenRenderer::new);
        EntityRendererRegistry.register(ModEntities.RASENSHURIKEN, com.example.shinobicore.entity.RasenshurikenRenderer::new);
        EntityRendererRegistry.register(ModEntities.RASENGAN_HAND, com.example.shinobicore.entity.RasenganHandRenderer::new);
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
        ShinobiCore.LOGGER.info("Registered cinematic camera");

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CHAKRA_SYNC_ID, (client, handler, buf, responseSender) -> {
            ChakraSyncPacket packet = ChakraSyncPacket.read(buf);
            client.execute(() -> {
                ChakraHudRenderer.currentChakra = packet.currentChakra();
                ChakraHudRenderer.maxChakra = packet.maxChakra();
                ChakraHudRenderer.fatigue = packet.fatigue();
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
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.TREE_SYNC_ID, (client, handler, buf, responseSender) -> {
            int count = buf.readInt();
            Set<String> nodes = new HashSet<>();
            for (int i = 0; i < count; i++) nodes.add(buf.readString());
            client.execute(() -> {
                ClientNinjaState.unlockedNodes.clear();
                ClientNinjaState.unlockedNodes.addAll(nodes);
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
                ClientPlayNetworking.registerGlobalReceiver(ModPackets.HIT_STOP_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            int durationMs = buf.readInt();
            client.execute(() -> HitStopManager.freeze(entityId, durationMs));
        });
        ClientPlayConnectionEvents.DISCONNECT.register((handler, client) -> {
            IdlePoseSystem.cleanupAll();
            com.example.shinobicore.client.combat.TaijutsuAnimations.cleanup(client.player.getUuid());
            com.example.shinobicore.client.combat.KenjutsuAnimations.cleanup(client.player.getUuid());
            CastingClientState.clear();
            HitStopManager.clear();
            HandSignsClientState.clear();
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
        // HUD registration now inside ChakraHudRenderer.register() (self-guarded)
        HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);
    }
}
