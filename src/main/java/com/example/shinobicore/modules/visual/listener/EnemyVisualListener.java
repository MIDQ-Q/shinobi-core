package com.example.shinobicore.modules.visual.listener;

import com.example.shinobicore.modules.visual.particle.ParticleService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.stub.StubEvents;
import com.example.shinobicore.modules.visual.util.EffectRateLimiter;
import com.example.shinobicore.modules.visual.util.ParticleColors;
import net.minecraft.util.math.Vec3d;

public final class EnemyVisualListener {

    public static void onEnemyStateChanged(StubEvents.EnemyStateChangedEvent event) {
        if (!EffectRateLimiter.canPlayEffect("enemy_state_" + event.entityId)) return;

        Vec3d pos = event.pos;
        int color = ParticleColors.WHITE;

        switch (event.newState.toLowerCase()) {
            case "chase": color = ParticleColors.RED; break;
            case "attack": color = ParticleColors.FIRE; break;
            case "cast": color = ParticleColors.LIGHTNING; break;
            case "retreat": color = ParticleColors.GRAY; break;
            default: return;
        }

        for (int i = 0; i < 5; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            float vx = (float)(Math.random() - 0.5) * 0.05f;
            float vy = 0.05f + (float)(Math.random() * 0.05f);
            float vz = (float)(Math.random() - 0.5) * 0.05f;
            p.init((float)pos.x, (float)pos.y + 1.5f, (float)pos.z, vx, vy, vz, color, 15);
            ParticleService.onParticleSpawned();
        }
        EffectRateLimiter.onEffectPlayed("enemy_state_" + event.entityId);
    }
}