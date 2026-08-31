package com.example.shinobicore.modules.visual.command;

import com.example.shinobicore.modules.visual.aura.AuraService;
import com.example.shinobicore.modules.visual.camera.CameraShakeService;
import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.example.shinobicore.modules.visual.particle.ParticleService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.pool.TrailPool;
import com.example.shinobicore.modules.visual.screen.ScreenFlashService;
import com.example.shinobicore.modules.visual.trail.TrailService;
import net.fabricmc.fabric.api.client.command.v2.FabricClientCommandSource;
import net.minecraft.client.MinecraftClient;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import net.minecraft.util.math.Vec3d;

public final class VisualClientCommands {

    public static void executeTest(FabricClientCommandSource source) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        Vec3d pos = client.player.getPos().add(0, 1.5, 0);

        for (int i = 0; i < 50; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            double angle = Math.random() * Math.PI * 2;
            double pitch = Math.random() * Math.PI - Math.PI / 2;
            float vx = (float)(Math.cos(angle) * Math.cos(pitch)) * 0.1f;
            float vy = (float)Math.sin(pitch) * 0.1f;
            float vz = (float)(Math.sin(angle) * Math.cos(pitch)) * 0.1f;
            p.init((float)pos.x, (float)pos.y, (float)pos.z, vx, vy, vz, 0xFFFF00FF, 40);
            ParticleService.onParticleSpawned();
        }
        TrailService.spawnTrail((float)pos.x, (float)pos.y, (float)pos.z,
            (float)pos.x + 2.0f, (float)pos.y + 1.0f, (float)pos.z, 0xFF00FF00, 0.1f, 20);
        CameraShakeService.shake(2.0f, 20);
        source.sendFeedback(Text.literal("Visual Test Executed!").formatted(Formatting.GREEN));
    }

    public static void executeInfo(FabricClientCommandSource source) {
        VisualConfig cfg = VisualConfig.get();
        source.sendFeedback(Text.literal("=== Visual Module Info ===").formatted(Formatting.GOLD));
        source.sendFeedback(Text.literal("Particles: " + ParticlePool.getActiveCount() + "/" + cfg.particles.poolSize).formatted(Formatting.AQUA));
        source.sendFeedback(Text.literal("Trails: " + TrailPool.getActiveCount() + "/" + cfg.trails.poolSize).formatted(Formatting.AQUA));
        source.sendFeedback(Text.literal("Aura: " + (AuraService.isChakraModeActive() ? "ON" : "OFF")).formatted(Formatting.AQUA));
        source.sendFeedback(Text.literal("Shake: " + (CameraShakeService.isShaking() ? "ON" : "OFF")).formatted(Formatting.AQUA));
        source.sendFeedback(Text.literal("Flash: " + (ScreenFlashService.isFlashing() ? "ON" : "OFF")).formatted(Formatting.AQUA));
        source.sendFeedback(Text.literal("Preset: " + cfg.qualityPreset).formatted(Formatting.AQUA));
        source.sendFeedback(Text.literal("Cull: " + cfg.culling.distance + " blocks").formatted(Formatting.AQUA));
    }

    public static void executeClear(FabricClientCommandSource source) {
        ParticlePool.init(VisualConfig.get().particles.poolSize);
        TrailPool.init(VisualConfig.get().trails.poolSize);
        CameraShakeService.init();
        ScreenFlashService.init();
        AuraService.init();
        source.sendFeedback(Text.literal("All visual effects cleared.").formatted(Formatting.YELLOW));
    }

    public static void executeDebug(FabricClientCommandSource source) {
        VisualConfig cfg = VisualConfig.get();
        cfg.debug = !cfg.debug;
        source.sendFeedback(Text.literal("Debug overlay: " + (cfg.debug ? "ON" : "OFF")).formatted(Formatting.YELLOW));
    }

    public static void executePreset(FabricClientCommandSource source, String preset) {
        VisualConfig cfg = VisualConfig.get();
        switch (preset.toLowerCase()) {
            case "low":
                cfg.particles.maxPerFrame = 20;
                cfg.particles.maxPerSecond = 80;
                cfg.culling.distance = 16.0;
                cfg.cameraShake.enabled = false;
                cfg.trails.enabled = false;
                break;
            case "medium":
                cfg.particles.maxPerFrame = 35;
                cfg.particles.maxPerSecond = 140;
                cfg.culling.distance = 24.0;
                cfg.cameraShake.enabled = true;
                cfg.trails.enabled = true;
                break;
            case "high":
            case "default":
                cfg.particles.maxPerFrame = 50;
                cfg.particles.maxPerSecond = 200;
                cfg.culling.distance = 32.0;
                cfg.cameraShake.enabled = true;
                cfg.trails.enabled = true;
                break;
            default:
                source.sendFeedback(Text.literal("Unknown preset: " + preset).formatted(Formatting.RED));
                return;
        }
        cfg.qualityPreset = preset.toLowerCase();
        source.sendFeedback(Text.literal("Quality preset set to: " + preset).formatted(Formatting.GREEN));
    }

    public static void executeFlash(FabricClientCommandSource source) {
        ScreenFlashService.flash(0xFFFFD700, 30);
        source.sendFeedback(Text.literal("Screen Flash triggered!").formatted(Formatting.GOLD));
    }

    public static void executeAura(FabricClientCommandSource source) {
        boolean current = AuraService.isChakraModeActive();
        if (current) AuraService.onChakraModeDisabled(null);
        else AuraService.onChakraModeEnabled(null);
        source.sendFeedback(Text.literal("Chakra Aura: " + (!current ? "ON" : "OFF")).formatted(Formatting.AQUA));
    }
}