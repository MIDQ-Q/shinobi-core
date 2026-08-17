package com.example.shinobicore.client.vfx.particles;

import net.minecraft.util.math.Vec3d;

/**
 * S5-05: Element-colored particle presets.
 * Static methods for spawning themed particle effects.
 */
public class VoxelParticleEmitter {

    /** Fire burst: orange/red particles. */
    public static void fireBurst(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            1.0f, 0.4f, 0.1f, 0.9f, 0.12f, 25, true, spread);
    }

    /** Water splash: blue particles. */
    public static void waterSplash(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.2f, 0.5f, 1.0f, 0.8f, 0.1f, 20, false, spread);
    }

    /** Wind gust: pale green particles. */
    public static void windGust(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.6f, 0.9f, 0.7f, 0.6f, 0.08f, 15, false, spread);
    }

    /** Lightning spark: yellow particles. */
    public static void lightningSpark(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            1.0f, 1.0f, 0.3f, 0.9f, 0.08f, 12, true, spread);
    }

    /** Earth crumble: brown particles. */
    public static void earthCrumble(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.6f, 0.45f, 0.2f, 0.8f, 0.12f, 20, false, spread);
    }

    /** Chakra flow: blue-white particles. */
    public static void chakraFlow(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.4f, 0.7f, 1.0f, 0.7f, 0.06f, 18, true, spread);
    }

    /** Smoke: gray particles. */
    public static void smoke(Vec3d pos, int count, float spread) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, count,
            0.5f, 0.5f, 0.5f, 0.5f, 0.15f, 30, false, spread * 0.5f);
    }

    /** Kawarimi poof: large smoke burst. */
    public static void kawarimiPoof(Vec3d pos) {
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, 40,
            0.6f, 0.6f, 0.6f, 0.6f, 0.2f, 35, false, 0.4f);
    }

    /** Clone dispersion: smoke + sparks. */
    public static void cloneDispersion(Vec3d pos) {
        smoke(pos, 25, 0.5f);
        VoxelParticleManager.spawnBurst(
            (float)pos.x, (float)pos.y, (float)pos.z, 15,
            0.8f, 0.8f, 1.0f, 0.8f, 0.05f, 10, true, 0.3f);
    }
}