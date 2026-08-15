package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class RasenshurikenRenderer extends EntityRenderer<RasenshurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public RasenshurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(RasenshurikenEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();
        matrices.translate(0, 0.3, 0);

        float rotation = (entity.age + tickDelta) * 15f;
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation));

        // 4 ЛЕЗВИЯ
        for (int i = 0; i < 4; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(i * 90));
            Matrix4f m = matrices.peek().getPositionMatrix();
            float len = 1.5f;
            float width = 0.3f;
            VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
            // Верхняя грань
            emitQuad(consumer, m, 0, 0.05f, 0, len, 0.05f, -width, len, 0.05f, width, 0, 0.05f, 0, 0.3f, 0.6f, 1.0f, 0.9f, light);
            // Нижняя грань
            emitQuad(consumer, m, 0, -0.05f, 0, len, -0.05f, width, len, -0.05f, -width, 0, -0.05f, 0, 0.2f, 0.4f, 0.9f, 0.8f, light);
            // Передняя грань
            emitQuad(consumer, m, 0, -0.05f, 0, len, -0.05f, -width, len, 0.05f, -width, 0, 0.05f, 0, 0.4f, 0.7f, 1.0f, 0.85f, light);
            // Задняя грань
            emitQuad(consumer, m, 0, 0.05f, 0, len, 0.05f, width, len, -0.05f, width, 0, -0.05f, 0, 0.4f, 0.7f, 1.0f, 0.85f, light);
            matrices.pop();
        }

        // ЦЕНТРАЛЬНАЯ СФЕРА
        renderSphere(matrices, vc, 0.35f, 0.2f, 0.5f, 1.0f, 0.95f, light);
        // КОЛЬЦО
        renderRing(matrices, vc, 0.6f, 0.08f, 0.5f, 0.8f, 1.0f, 0.7f, light);
        // СВЕЧЕНИЕ
        renderSphere(matrices, vc, 0.55f, 0.3f, 0.6f, 1.0f, 0.3f, light);

        matrices.pop();
    }

    private void renderSphere(MatrixStack matrices, VertexConsumerProvider vc,
                              float radius, float r, float g, float b, float a, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        float half = radius;
        for (int i = 0; i < 3; i++) {
            float angle = i * 60f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
            matrices.pop();
        }
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitQuad(consumer, mH, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
        matrices.pop();
    }

    private void renderRing(MatrixStack matrices, VertexConsumerProvider vc,
                            float radius, float thickness, float r, float g, float b, float a, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        int segments = 16;
        for (int i = 0; i < segments; i++) {
            float a1 = (float)(i * 2 * Math.PI / segments);
            float a2 = (float)((i + 1) * 2 * Math.PI / segments);
            float x1 = (float) Math.cos(a1) * radius;
            float z1 = (float) Math.sin(a1) * radius;
            float x2 = (float) Math.cos(a2) * radius;
            float z2 = (float) Math.sin(a2) * radius;
            float ix1 = (float) Math.cos(a1) * (radius - thickness);
            float iz1 = (float) Math.sin(a1) * (radius - thickness);
            float ix2 = (float) Math.cos(a2) * (radius - thickness);
            float iz2 = (float) Math.sin(a2) * (radius - thickness);
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, x1, thickness, z1, x2, thickness, z2, ix2, thickness, iz2, ix1, thickness, iz1, r, g, b, a, light);
            emitQuad(consumer, m, ix1, -thickness, iz1, ix2, -thickness, iz2, x2, -thickness, z2, x1, -thickness, z1, r, g, b, a, light);
        }
    }

    private void emitQuad(VertexConsumer consumer, Matrix4f matrix,
                          float x1, float y1, float z1, float x2, float y2, float z2,
                          float x3, float y3, float z3, float x4, float y4, float z4,
                          float r, float g, float b, float a, int light) {
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix,
                        float x, float y, float z, float u, float v,
                        float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z).color(r, g, b, a).texture(u, v)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override
    public Identifier getTexture(RasenshurikenEntity entity) { return TEX; }
}