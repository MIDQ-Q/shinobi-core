package com.example.shinobicore.client.vfx;

import net.minecraft.client.MinecraftClient;

/**
 * S5-08: Performance optimizer for voxel rendering.
 * Handles: mesh baking control, buffer reuse tracking,
 * internal cube culling, dragon segment limits,
 * dynamic quality adjustment based on FPS.
 */
public class VoxelPerformanceOptimizer {

    private static int maxDragonSegments = 12;
    private static int maxActiveMeshes = 50;
    private static int currentActiveMeshes = 0;
    private static boolean enableInternalCulling = true;

    /**
     * Check if we can render more meshes this frame.
     */
    public static boolean canRenderMesh() {
        return currentActiveMeshes < maxActiveMeshes;
    }

    public static void registerMesh() { currentActiveMeshes++; }

    public static void unregisterMesh() {
        currentActiveMeshes = Math.max(0, currentActiveMeshes - 1);
    }

    /**
     * Reset frame counter. Call at start of each render frame.
     */
    public static void resetFrame() { currentActiveMeshes = 0; }

    /**
     * Max dragon segments based on performance settings.
     */
    public static int getMaxDragonSegments() { return maxDragonSegments; }

    public static void setMaxDragonSegments(int segments) {
        maxDragonSegments = Math.max(4, Math.min(20, segments));
    }

    /**
     * Internal cube culling: skip cubes fully surrounded by others.
     */
    public static boolean isInternalCullingEnabled() { return enableInternalCulling; }

    public static void setInternalCulling(boolean enabled) {
        enableInternalCulling = enabled;
    }

    /**
     * Get current FPS for dynamic quality adjustment.
     */
    public static int getCurrentFps() {
        MinecraftClient client = MinecraftClient.getInstance();
        return client != null ? client.getCurrentFps() : 60;
    }

    /**
     * Dynamic quality multiplier based on FPS.
     * Returns 0.5-1.0 for particle count and mesh detail scaling.
     */
    public static float getQualityMultiplier() {
        int fps = getCurrentFps();
        if (fps < 30) return 0.5f;
        if (fps < 45) return 0.7f;
        if (fps < 60) return 0.85f;
        return 1.0f;
    }

    /**
     * Check if a cube is fully internal (all 6 faces hidden).
     * Used to skip rendering invisible cubes in dense models.
     */
    public static boolean isCubeInternal(VoxelModel model, int cubeIndex) {
        if (!enableInternalCulling) return false;
        var cubes = model.getCubes();
        if (cubeIndex < 0 || cubeIndex >= cubes.size()) return false;

        VoxelCube cube = cubes.get(cubeIndex);
        float cx = cube.x(), cy = cube.y(), cz = cube.z();
        float hw = cube.w() / 2f, hh = cube.h() / 2f, hd = cube.d() / 2f;

        boolean hasLeft = false, hasRight = false, hasTop = false;
        boolean hasBottom = false, hasFront = false, hasBack = false;

        for (int i = 0; i < cubes.size(); i++) {
            if (i == cubeIndex) continue;
            VoxelCube other = cubes.get(i);
            float dx = Math.abs(other.x() - cx);
            float dy = Math.abs(other.y() - cy);
            float dz = Math.abs(other.z() - cz);

            if (dy <= hh + 0.01f && dz <= hd + 0.01f) {
                if (dx <= hw + other.w() / 2f + 0.01f) {
                    if (other.x() < cx) hasLeft = true;
                    if (other.x() > cx) hasRight = true;
                }
            }
            if (dx <= hw + 0.01f && dz <= hd + 0.01f) {
                if (dy <= hh + other.h() / 2f + 0.01f) {
                    if (other.y() < cy) hasBottom = true;
                    if (other.y() > cy) hasTop = true;
                }
            }
            if (dx <= hw + 0.01f && dy <= hh + 0.01f) {
                if (dz <= hd + other.d() / 2f + 0.01f) {
                    if (other.z() < cz) hasBack = true;
                    if (other.z() > cz) hasFront = true;
                }
            }
        }
        return hasLeft && hasRight && hasTop && hasBottom && hasFront && hasBack;
    }
}