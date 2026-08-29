package com.example.shinobicore.client.vfx;

import com.example.shinobicore.ShinobiCore;

/**
 * S4-08 groundwork: Budget limiter for active voxel effects.
 * Prevents performance degradation from VFX spam.
 *
 * Usage:
 *   if (!VfxBudget.canSpawn()) return;
 *   VfxBudget.register();
 *   ... spawn effect ...
 *   VfxBudget.unregister(); // on effect end
 */
public class VfxBudget {

    private static int activeVfx = 0;
    private static int maxGlobalVfx = 50;
    private static int maxPerPlayerVfx = 10;
    private static int maxParticlesPerEffect = 200;

    public static void register() {
        activeVfx++;
    }

    public static void unregister() {
        activeVfx = Math.max(0, activeVfx - 1);
    }

    public static boolean canSpawn() {
        return activeVfx < maxGlobalVfx;
    }

    public static int getActiveCount() {
        return activeVfx;
    }

    public static void setMaxGlobalVfx(int max) {
        maxGlobalVfx = Math.max(1, max);
        ShinobiCore.LOGGER.debug("[VFX] Max global VFX set to {}", maxGlobalVfx);
    }

    public static void setMaxPerPlayerVfx(int max) {
        maxPerPlayerVfx = Math.max(1, max);
    }

    public static void setMaxParticlesPerEffect(int max) {
        maxParticlesPerEffect = Math.max(10, max);
    }

    public static int getMaxGlobalVfx() { return maxGlobalVfx; }
    public static int getMaxPerPlayerVfx() { return maxPerPlayerVfx; }
    public static int getMaxParticlesPerEffect() { return maxParticlesPerEffect; }

    /** Reset on disconnect. */
    public static void reset() {
        activeVfx = 0;
    }
}