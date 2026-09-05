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
import com.example.shinobicore.core.event.ClientEventBus;
import com.example.shinobicore.client.ClientNinjaStateHolder;
public class ShinobiCoreClient implements ClientModInitializer {

    @Override
    public void onInitializeClient() {
        KeyBindings.register();
        ClientInputHandler.register();
        ChakraPhysicsClient.register();
        ParkourManager.register();
        TaijutsuClientHandler.register();
        RasenganClientVisual.register();
        com.example.shinobicore.client.ChakraAuraVisual.register();
        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
        // TargetFrameHud disabled by design (HUD v3)
        com.example.shinobicore.client.RpgCameraKeybind.register(); // PHASE_H_CAMERA // BATCH3_AURA
        com.example.shinobicore.client.LandingAnimations.register(); // PHASE_A_REG
        // === РЕГИСТРАЦИЯ РЕНДЕРЕРОВ (было потеряно!) ===
        EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);
        EntityRendererRegistry.register(ModEntities.SHURIKEN, ShurikenRenderer::new);
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
                ClientNinjaStateHolder.get().setMeditating(packet.meditating());
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CATALOG_SYNC_ID, (client, handler, buf, responseSender) -> {
            Map<String, String> cat = new HashMap<>();
            int n = buf.readInt();
            for (int i = 0; i < n; i++) cat.put(buf.readString(), buf.readString());
            client.execute(() -> {
                ClientNinjaStateHolder.get().getCatalog().clear();
                ClientNinjaStateHolder.get().getCatalog().putAll(cat);
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
                ClientNinjaStateHolder.get().setActiveA(aA); ClientNinjaStateHolder.get().setActiveB(aB);
                for (int i = 0; i < 5; i++) { ClientNinjaStateHolder.get().getLoadoutA()[i] = la[i]; ClientNinjaStateHolder.get().getLoadoutB()[i] = lb[i]; }
                ClientNinjaStateHolder.get().getLearned().clear();
                ClientNinjaStateHolder.get().getLearned().addAll(learned);
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
                ClientNinjaStateHolder.get().setSkillPoints(sp);
                ClientNinjaStateHolder.get().setReserveLevel(resLvl);
                ClientNinjaStateHolder.get().setReserveXp(resXp);
                ClientNinjaStateHolder.get().getStatLevels().clear(); ClientNinjaStateHolder.get().getStatLevels().putAll(sl);
                ClientNinjaStateHolder.get().getStatXp().clear(); ClientNinjaStateHolder.get().getStatXp().putAll(sx);
                ClientNinjaStateHolder.get().getNatureLevels().clear(); ClientNinjaStateHolder.get().getNatureLevels().putAll(nl);
                ClientNinjaStateHolder.get().getNatureXp().clear(); ClientNinjaStateHolder.get().getNatureXp().putAll(nx);
                ClientNinjaStateHolder.get().getNatureUnlocked().clear(); ClientNinjaStateHolder.get().getNatureUnlocked().putAll(nu);
                ClientNinjaStateHolder.get().setSensoryEnabled(sen);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.BODY_SYNC_ID, (client, handler, buf, responseSender) -> {
            int hp = buf.readInt(); int speed = buf.readInt(); int jump = buf.readInt();
            boolean chakra = buf.readBoolean(); String clan = buf.readString(); String affinity = buf.readString();
            client.execute(() -> {
                ClientNinjaStateHolder.get().setHpLevel(hp);
                ClientNinjaStateHolder.get().setSpeedLevel(speed);
                ClientNinjaStateHolder.get().setJumpLevel(jump);
                ClientNinjaStateHolder.get().setChakraMode(chakra);
                ClientNinjaStateHolder.get().setClanId(clan.isEmpty() ? "none" : clan);
                ClientNinjaStateHolder.get().setAffinityId(affinity.isEmpty() ? null : affinity);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.TREE_SYNC_ID, (client, handler, buf, responseSender) -> {
            int count = buf.readInt();
            Set<String> nodes = new HashSet<>();
            for (int i = 0; i < count; i++) nodes.add(buf.readString());
            client.execute(() -> {
                ClientNinjaStateHolder.get().getUnlockedNodes().clear();
                ClientNinjaStateHolder.get().getUnlockedNodes().addAll(nodes);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID, (client, handler, buf, responseSender) -> {
            boolean danger = buf.readBoolean();
            client.execute(() -> ClientNinjaStateHolder.get().setDangerSense(danger));
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
        VoxelCastVisual.register();
        com.example.shinobicore.client.combat.SwordTrailRenderer.register(); // PHASE_K1_TRAIL_REGISTERED
        ChakraAuraRenderer.register(); // PHASE_E_AURA_REGISTERED
                ClientPlayNetworking.registerGlobalReceiver(ModPackets.HIT_STOP_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            int durationMs = buf.readInt();
            client.execute(() -> HitStopManager.freeze(entityId, durationMs));
        });
        ClientPlayConnectionEvents.DISCONNECT.register((handler, client) -> {
            ClientEventBus.clearAll();
            // Phase 2: Clean rate limiter
            if (client.player != null) {
                com.example.shinobicore.network.PacketRateLimiter.removePlayer(client.player.getUuid());
            }
            IdlePoseSystem.cleanupAll();
            com.example.shinobicore.client.combat.TaijutsuAnimations.cleanupAll();
            com.example.shinobicore.client.combat.KenjutsuAnimations.cleanupAll();
            com.example.shinobicore.client.combat.ChakraBurstAnimations.cleanupAll();
            CastingClientState.clear();
            HitStopManager.clear();
            HandSignsClientState.clear();
            RasenganClientState.reset();
            com.example.shinobicore.client.combat.TaichiComboVariants.cleanupAll();
            com.example.shinobicore.client.combat.ThrowAnimations.cleanupAll();
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
        com.example.shinobicore.ai.client.AiRenderers.register();
        com.example.shinobicore.client.JutsuKeybindClient.register();
        com.example.shinobicore.client.CooldownHudState.register();
    }
}
