package com.example.shinobicore.modules.visual.listener;

import com.example.shinobicore.modules.visual.stub.StubEvents.JutsuCastStartedEvent;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.particle.ParticleService;
import com.example.shinobicore.modules.visual.util.EffectRateLimiter;
import net.minecraft.util.math.Vec3d;

public final class JutsuVisualListener {
    public static void onCastStarted(JutsuCastStartedEvent event) {
        if (!EffectRateLimiter.canPlayEffect("cast_" + event.elementId)) return;
        
        Vec3d pos = event.caster.getPos().add(0, 1.2, 0);
        int color = 0xFF00FFFF;
        
        for (int i = 0; i < 20; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            
            float angle = (float)(Math.random() * Math.PI * 2);
            float speed = 0.05f + (float)(Math.random() * 0.1f);
            p.init((float)pos.x, (float)pos.y, (float)pos.z, 
                   (float)Math.cos(angle) * speed, 0.1f + (float)Math.random() * 0.1f, (float)Math.sin(angle) * speed, 
                   color, 30);
            ParticleService.onParticleSpawned();
        }
        EffectRateLimiter.onEffectPlayed("cast_" + event.elementId);
    }
}