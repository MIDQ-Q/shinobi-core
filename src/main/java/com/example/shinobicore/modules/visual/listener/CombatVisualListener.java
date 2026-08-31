package com.example.shinobicore.modules.visual.listener;

import com.example.shinobicore.modules.visual.stub.StubEvents.CombatHitEvent;
import com.example.shinobicore.modules.visual.camera.CameraShakeService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.particle.ParticleService;
import net.minecraft.util.math.Vec3d;

public final class CombatVisualListener {
    public static void onHit(CombatHitEvent event) {
        Vec3d pos = event.attacker.getPos().add(0, 1.0, 0);
        
        for (int i = 0; i < 10; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            
            float vx = (float)(Math.random() - 0.5) * 0.2f;
            float vy = (float)(Math.random()) * 0.2f;
            float vz = (float)(Math.random() - 0.5) * 0.2f;
            p.init((float)pos.x, (float)pos.y, (float)pos.z, vx, vy, vz, 0xFFFFFF00, 10);
            ParticleService.onParticleSpawned();
        }
        
        float intensity = Math.min(event.damage / 10.0f, 3.0f);
        CameraShakeService.shake(intensity, 10);
    }
}