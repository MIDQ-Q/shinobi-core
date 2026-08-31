package com.example.shinobicore.modules.visual.listener;

import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.example.shinobicore.modules.visual.particle.ParticleService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.stub.StubEvents;
import com.example.shinobicore.modules.visual.util.EffectRateLimiter;
import com.example.shinobicore.modules.visual.util.ParticleColors;
import net.minecraft.util.math.Vec3d;

public final class MovementVisualListener {

    public static void onWaterWalkStarted(StubEvents.WaterWalkStartedEvent event) {
        if (!VisualConfig.get().movement.waterRipple) return;
        if (!EffectRateLimiter.canPlayEffect("water_ripple")) return;
        emitRipple(event.player.getPos(), ParticleColors.WATER, 15);
        EffectRateLimiter.onEffectPlayed("water_ripple");
    }

    public static void onWallRunStarted(StubEvents.WallRunStartedEvent event) {
        if (!VisualConfig.get().movement.wallRunDust) return;
        if (!EffectRateLimiter.canPlayEffect("wallrun_dust")) return;
        emitDust(event.player.getPos(), ParticleColors.GRAY, 5);
        EffectRateLimiter.onEffectPlayed("wallrun_dust");
    }

    public static void onSlideStarted(StubEvents.SlideStartedEvent event) {
        if (!VisualConfig.get().movement.slideDust) return;
        if (!EffectRateLimiter.canPlayEffect("slide_dust")) return;
        emitDust(event.player.getPos(), ParticleColors.BROWN, 6);
        EffectRateLimiter.onEffectPlayed("slide_dust");
    }

    public static void onRollStarted(StubEvents.RollStartedEvent event) {
        if (!VisualConfig.get().movement.rollDust) return;
        if (!EffectRateLimiter.canPlayEffect("roll_dust")) return;
        emitDust(event.player.getPos(), ParticleColors.BROWN, 8);
        EffectRateLimiter.onEffectPlayed("roll_dust");
    }

    public static void onDodge(StubEvents.DodgeEvent event) {
        if (!VisualConfig.get().movement.dodgeBlur) return;
        if (!EffectRateLimiter.canPlayEffect("dodge_blur")) return;
        emitDust(event.player.getPos(), ParticleColors.WHITE, 12);
        EffectRateLimiter.onEffectPlayed("dodge_blur");
    }

    private static void emitRipple(Vec3d pos, int color, int count) {
        for (int i = 0; i < count; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            float angle = (float)(Math.random() * Math.PI * 2);
            float speed = 0.05f + (float)(Math.random() * 0.08f);
            p.init((float)pos.x, (float)pos.y + 0.1f, (float)pos.z,
                   (float)Math.cos(angle) * speed, 0.02f, (float)Math.sin(angle) * speed,
                   color, 20);
            ParticleService.onParticleSpawned();
        }
    }

    private static void emitDust(Vec3d pos, int color, int count) {
        for (int i = 0; i < count; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            float vx = (float)(Math.random() - 0.5) * 0.1f;
            float vy = (float)(Math.random()) * 0.08f;
            float vz = (float)(Math.random() - 0.5) * 0.1f;
            p.init((float)pos.x, (float)pos.y + 0.2f, (float)pos.z, vx, vy, vz, color, 10);
            ParticleService.onParticleSpawned();
        }
    }
}