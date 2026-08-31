package com.example.shinobicore.modules.visual.render;

import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.math.Vec3d;

public final class VisualRenderDispatcher {

    public static void register() {
        WorldRenderEvents.AFTER_ENTITIES.register(VisualRenderDispatcher::onRender);
    }

    private static void onRender(WorldRenderContext context) {
        MatrixStack matrices = context.matrixStack();
        VertexConsumerProvider consumers = context.consumers();
        Vec3d cameraPos = context.camera().getPos();
        float tickDelta = context.tickDelta();

        matrices.push();

        ParticleRenderer.render(matrices, consumers, cameraPos, tickDelta);
        TrailRenderer.render(matrices, consumers, cameraPos);

        matrices.pop();
    }
}