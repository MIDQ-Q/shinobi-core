package com.example.shinobicore.modules.visual.culling;

import net.minecraft.client.MinecraftClient;

public final class EffectCullingService {
    private static double cullDistanceSq = 1024.0; // 32.0 * 32.0

    public static void init(double distance) {
        cullDistanceSq = distance * distance;
    }

    // Zero-allocation: pass raw floats instead of creating Vec3d
    public static boolean shouldRenderEffect(float x, float y, float z) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return false;
        
        double dx = client.player.getX() - x;
        double dy = client.player.getY() - y;
        double dz = client.player.getZ() - z;
        
        return (dx * dx + dy * dy + dz * dz) <= cullDistanceSq;
    }
}