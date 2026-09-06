package com.example.shinobicore.client.voxel;

import com.example.shinobicore.client.HandSignsClientState;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.math.RotationAxis;
import net.minecraft.util.math.Vec3d;

public final class HandheldVoxelRenderer {
    private HandheldVoxelRenderer() {}

    public static void render(WorldRenderContext ctx) {
        MinecraftClient client = MinecraftClient.getInstance();
        AbstractClientPlayerEntity player = client.player;
        if (player == null || client.world == null) return;
        HandSignsClientState.ActiveSigns s = HandSignsClientState.get(player.getId());
        if (s == null) return;
        JutsuDefinition def = JutsuRegistry.get(s.jutsuId);
        if (def == null || def.getForm() == null) return;
        if (!"handheld".equals(def.getForm().getType())) return;
        if (def.getVisual() == null || def.getVisual().getVoxelModel() == null) return;
        String model = def.getVisual().getVoxelModel();
        if (model.isEmpty()) return;
        if (VoxelModelRegistry.get(model) == null) return;

        Vec3d cam = ctx.camera().getPos();
        MatrixStack ms = ctx.matrixStack();
        VertexConsumerProvider vc = ctx.consumers();
        ms.push();
        ms.translate(player.getX() - cam.x, player.getY() - cam.y + 1.2, player.getZ() - cam.z);
        float yaw = player.getYaw(ctx.tickDelta());
        ms.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(-yaw));
        float spin = (player.age + ctx.tickDelta()) * 8f;
        ms.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(spin));
        ms.translate(0.6, 0, 0.2);
        float[] off = VoxelRotationConfig.get(model);
        ms.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(off[0]));
        ms.multiply(RotationAxis.POSITIVE_X.rotationDegrees(off[1]));
        ms.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(off[2]));
        float sc = (float) def.getVisual().getScale();
        if (sc <= 0) sc = 1.0f;
        ClientVoxelProjectiles.renderAt(ms, vc, model, sc);
        ms.pop();
    }
}