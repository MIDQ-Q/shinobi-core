package com.example.shinobicore.client.vfx;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.math.Vec3d;

/**
 * S4-07: Central voxel render manager.
 * Handles LOD selection, frustum culling, and distance-based optimization.
 * All voxel effect rendering should go through this class.
 */
public class VoxelRenderManager {
    
    /**
     * Render a voxel model with automatic LOD and culling.
     * Returns false if the model was culled (not rendered).
     */
    public static boolean renderOptimized(
            MatrixStack matrices, 
            VertexConsumerProvider vcProvider,
            VoxelModel highDetailModel,
            VoxelModel lowDetailModel,
            Vec3d worldPos,
            float yaw, float pitch, float scale,
            int light) {
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return false;
        
        // === FRUSTUM & DISTANCE CULLING ===
        double distSq = client.player.getPos().squaredDistanceTo(worldPos);
        
        // Hard cull beyond max distance
        float cullDist = VoxelQualityConfig.cullDistance;
        if (distSq > cullDist * cullDist) return false;
        
        // Simple frustum check using dot product with look direction
        if (VoxelQualityConfig.enableFrustumCulling) {
            Vec3d toObj = worldPos.subtract(client.player.getEyePos()).normalize();
            Vec3d look = client.player.getRotationVector();
            double dot = look.dotProduct(toObj);
            // Behind camera check (allow some margin for large objects)
            if (dot < -0.3) return false;
        }
        
        // === LOD SELECTION ===
        float dist = (float) Math.sqrt(distSq);
        VoxelModel selectedModel;
        
        if (dist <= VoxelQualityConfig.lodNearDistance) {
            selectedModel = highDetailModel;
        } else if (dist <= VoxelQualityConfig.lodFarDistance) {
            selectedModel = (lowDetailModel != null) ? lowDetailModel : highDetailModel;
        } else {
            // Far distance: use lowest detail or skip if too small
            if (scale < 0.5f && dist > VoxelQualityConfig.lodFarDistance * 1.5f) return false;
            selectedModel = (lowDetailModel != null) ? lowDetailModel : highDetailModel;
        }
        
        if (selectedModel == null || selectedModel.getCubeCount() == 0) return false;
        
        // === RENDER ===
        VoxelEffectRenderer.render(matrices, vcProvider, selectedModel, yaw, pitch, scale, light);
        return true;
    }
    
    /**
     * Simplified render for single-model effects (no LOD variant).
     * Still applies culling.
     */
    public static boolean renderWithCulling(
            MatrixStack matrices,
            VertexConsumerProvider vcProvider,
            VoxelModel model,
            Vec3d worldPos,
            float yaw, float pitch, float scale,
            int light) {
        return renderOptimized(matrices, vcProvider, model, null, worldPos, yaw, pitch, scale, light);
    }
    
    /**
     * Check if particles should spawn based on quality settings.
     * Use this before spawning particle effects.
     */
    public static boolean shouldSpawnParticles() {
        return Math.random() < VoxelQualityConfig.particleDensity;
    }
    
    /**
     * Get adjusted particle count based on quality.
     */
    public static int adjustParticleCount(int baseCount) {
        return Math.max(1, (int)(baseCount * VoxelQualityConfig.particleDensity));
    }
}