package com.example.shinobicore.client.sensory;

import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.*;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import org.joml.Matrix4f;

/**
 * S6-04: Renders scan silhouettes in world space.
 * Entities appear as translucent outlines for 3 seconds after scan.
 * Silhouettes fade out gradually.
 */
public class SensoryScanRenderer {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public static void register() {
        WorldRenderEvents.AFTER_TRANSLUCENT.register(SensoryScanRenderer::render);
    }

    private static void render(WorldRenderContext context) {
        if (!SensoryClientState.isScanActive()) return;
        if (SensoryClientState.scanEntities.isEmpty()) return;

        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        float alpha = SensoryClientState.getScanAlpha();
        if (alpha <= 0.01f) return;

        MatrixStack matrices = context.matrixStack();
        VertexConsumerProvider consumers = context.consumers();
        if (consumers == null) return;

        Vec3d camPos = context.camera().getPos();
        VertexConsumer vc = consumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));

        matrices.push();
        matrices.translate(-camPos.x, -camPos.y, -camPos.z);

        for (SensoryClientState.ScanEntity entity : SensoryClientState.scanEntities) {
            float r, g, b;
            if (entity.isHostile) {
                r = 1.0f; g = 0.2f; b = 0.2f; // Red for hostile
            } else {
                r = 0.2f; g = 0.8f; b = 1.0f; // Cyan for passive
            }

            // Draw a simple box silhouette
            float halfW = 0.3f;
            float h = entity.height;
            float x = (float) entity.x;
            float y = (float) entity.y;
            float z = (float) entity.z;

            Matrix4f m = matrices.peek().getPositionMatrix();

            // Front face
            emitQuad(vc, m, x - halfW, y, z + halfW, x + halfW, y, z + halfW,
                     x + halfW, y + h, z + halfW, x - halfW, y + h, z + halfW,
                     r, g, b, alpha * 0.4f);
            // Back face
            emitQuad(vc, m, x + halfW, y, z - halfW, x - halfW, y, z - halfW,
                     x - halfW, y + h, z - halfW, x + halfW, y + h, z - halfW,
                     r, g, b, alpha * 0.4f);
            // Left face
            emitQuad(vc, m, x - halfW, y, z - halfW, x - halfW, y, z + halfW,
                     x - halfW, y + h, z + halfW, x - halfW, y + h, z - halfW,
                     r, g, b, alpha * 0.3f);
            // Right face
            emitQuad(vc, m, x + halfW, y, z + halfW, x + halfW, y, z - halfW,
                     x + halfW, y + h, z - halfW, x + halfW, y + h, z + halfW,
                     r, g, b, alpha * 0.3f);
        }

        matrices.pop();
    }

    private static void emitQuad(VertexConsumer vc, Matrix4f m,
            float x1, float y1, float z1, float x2, float y2, float z2,
            float x3, float y3, float z3, float x4, float y4, float z4,
            float r, float g, float b, float a) {
        vc.vertex(m, x1, y1, z1).color(r, g, b, a)
          .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
          .light(0xF000F0).normal(0, 1, 0).next();
        vc.vertex(m, x2, y2, z2).color(r, g, b, a)
          .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
          .light(0xF000F0).normal(0, 1, 0).next();
        vc.vertex(m, x3, y3, z3).color(r, g, b, a)
          .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
          .light(0xF000F0).normal(0, 1, 0).next();
        vc.vertex(m, x4, y4, z4).color(r, g, b, a)
          .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
          .light(0xF000F0).normal(0, 1, 0).next();
    }
}