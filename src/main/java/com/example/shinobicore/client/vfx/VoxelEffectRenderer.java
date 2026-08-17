package com.example.shinobicore.client.vfx;

import net.minecraft.client.render.RenderLayer;
import com.example.shinobicore.client.render.ShaderCompatibilityManager;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import net.minecraft.util.math.Vec3d;

/**
 * S4-01: High-level renderer for voxel effects in the world.
 * Uses translucent render layer + white texture.
 * Emissive cubes automatically get max light via VoxelMeshBuilder.
 */
public class VoxelEffectRenderer {

    private static final Identifier TEX =
        new Identifier("textures/misc/white.png");

    /**
     * Render a voxel model at the current matrix position.
     * Caller must push/pop MatrixStack.
     */
    public static void render(MatrixStack matrices,
                              VertexConsumerProvider vcProvider,
                              VoxelModel model,
                              float yaw, float pitch, float scale,
                              int light) {
        if (model.getCubeCount() == 0) return;
        matrices.push();
        if (pitch != 0f) {
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(pitch));
        }
        if (yaw != 0f) {
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(yaw));
        }
        matrices.scale(scale, scale, scale);
        VertexConsumer vc =
            vcProvider.getBuffer(ShaderCompatibilityManager.getVfxLayer(TEX));
        VoxelMeshBuilder.renderModel(matrices, vc, model, light);
        matrices.pop();
    }

    /**
     * Render a voxel model at a world position.
     * Convenience wrapper that handles translate internally.
     */
    public static void renderAt(MatrixStack matrices,
                                VertexConsumerProvider vcProvider,
                                VoxelModel model,
                                Vec3d pos,
                                float yaw, float pitch, float scale,
                                int light) {
        matrices.push();
        matrices.translate(pos.x, pos.y, pos.z);
        render(matrices, vcProvider, model, yaw, pitch, scale, light);
        matrices.pop();
    }

    /**
     * Render with emissive glow (ignores world lighting).
     * All cubes treated as emissive regardless of their flag.
     */
    public static void renderGlow(MatrixStack matrices,
                                  VertexConsumerProvider vcProvider,
                                  VoxelModel model,
                                  float yaw, float pitch, float scale) {
        if (model.getCubeCount() == 0) return;
        matrices.push();
        if (pitch != 0f) {
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(pitch));
        }
        if (yaw != 0f) {
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(yaw));
        }
        matrices.scale(scale, scale, scale);
        VertexConsumer vc =
            vcProvider.getBuffer(ShaderCompatibilityManager.getVfxLayer(TEX));
        VoxelMeshBuilder.renderModel(matrices, vc, model, 0xF000F0);
        matrices.pop();
    }
}