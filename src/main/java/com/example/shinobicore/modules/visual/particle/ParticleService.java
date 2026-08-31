package com.example.shinobicore.modules.visual.particle;

import com.example.shinobicore.modules.visual.config.VisualConfig;

public final class ParticleService {
    private static int particlesThisFrame = 0;
    private static int particlesThisSecond = 0;
    private static int tickCounter = 0;

    public static void init() {
        particlesThisFrame = 0;
        particlesThisSecond = 0;
        tickCounter = 0;
    }

    public static boolean canSpawnParticle() {
        int maxFrame = VisualConfig.get().particles.maxPerFrame;
        int maxSec = VisualConfig.get().particles.maxPerSecond;
        
        if (particlesThisFrame >= maxFrame) return false;
        if (particlesThisSecond >= maxSec) return false;
        return true;
    }

    public static void onParticleSpawned() {
        particlesThisFrame++;
        particlesThisSecond++;
    }

    public static void tick() {
        particlesThisFrame = 0;
        tickCounter++;
        if (tickCounter % 20 == 0) {
            particlesThisSecond = 0;
        }
    }
}