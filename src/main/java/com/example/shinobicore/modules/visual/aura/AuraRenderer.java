package com.example.shinobicore.modules.visual.aura;

import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.mojang.blaze3d.systems.RenderSystem;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.*;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import org.joml.Matrix4f;

public final class AuraRenderer {

    public static void register() {
        WorldRenderEvents.AFTER_TRANSLUCENT.register(AuraRenderer::onRender);
    }

    private static void onRender(WorldRenderContext context) {
        if (!AuraService.isChakraModeActive()) return;

        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        MatrixStack matrices = context.matrixStack();
        Vec3d cameraPos = context.camera().getPos();
        float tickDelta = context.tickDelta();

        // Interpolate player position for smooth rendering
        double px = MathHelper.lerp(tickDelta, client.player.lastRenderX, client.player.getX());
        double py = MathHelper.lerp(tickDelta, client.player.lastRenderY, client.player.getY());
        double pz = MathHelper.lerp(tickDelta, client.player.lastRenderZ, client.player.getZ());

        float x = (float)(px - cameraPos.x);
        float y = (float)(py - cameraPos.y);
        float z = (float)(pz - cameraPos.z);

        RenderSystem.enableBlend();
        RenderSystem.defaultBlendFunc();
        RenderSystem.setShader(GameRenderer::getPositionColorProgram);

        BufferBuilder bufferBuilder = Tessellator.getInstance().getBuffer();
        bufferBuilder.begin(VertexFormat.DrawMode.QUADS, VertexFormats.POSITION_COLOR);

        Matrix4f matrix = matrices.peek().getPositionMatrix();

        // Pulsing effect (Zero-Allocation math)
        long time = System.currentTimeMillis();
        float pulse = 0.8f + 0.2f * (float)Math.sin(time / 200.0);
        float radius = 1.0f * pulse;

        int color = VisualConfig.get().auras.chakraAuraColor;
        float r = ((color >> 16) & 0xFF) / 255.0f;
        float g = ((color >> 8) & 0xFF) / 255.0f;
        float b = (color & 0xFF) / 255.0f;
        float a = 0.3f * pulse;

        // Draw a simple pulsing box around the player (Zero-Allocation)
        // Bottom
        bufferBuilder.vertex(matrix, x - radius, y, z - radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y, z - radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y, z + radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x - radius, y, z + radius).color(r, g, b, a).next();
        // Top
        bufferBuilder.vertex(matrix, x - radius, y + 2.0f, z - radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x - radius, y + 2.0f, z + radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y + 2.0f, z + radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y + 2.0f, z - radius).color(r, g, b, a).next();
        // Front
        bufferBuilder.vertex(matrix, x - radius, y, z + radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y, z + radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y + 2.0f, z + radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x - radius, y + 2.0f, z + radius).color(r, g, b, a).next();
        // Back
        bufferBuilder.vertex(matrix, x - radius, y, z - radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x - radius, y + 2.0f, z - radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y + 2.0f, z - radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y, z - radius).color(r, g, b, a).next();
        // Left
        bufferBuilder.vertex(matrix, x - radius, y, z - radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x - radius, y, z + radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x - radius, y + 2.0f, z + radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x - radius, y + 2.0f, z - radius).color(r, g, b, a).next();
        // Right
        bufferBuilder.vertex(matrix, x + radius, y, z - radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y + 2.0f, z - radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y + 2.0f, z + radius).color(r, g, b, a).next();
        bufferBuilder.vertex(matrix, x + radius, y, z + radius).color(r, g, b, a).next();

        BufferRenderer.drawWithGlobalProgram(bufferBuilder.end());
        RenderSystem.disableBlend();
    }
}