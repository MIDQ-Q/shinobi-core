package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {
    private static final Identifier WHITE_TEXTURE = new Identifier("textures/misc/white.png");

    public NinjaProjectileRenderer(EntityRendererFactory.Context ctx) {
        super(ctx);
    }

    @Override
    public void render(NinjaProjectileEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light) {
        super.render(entity, yaw, tickDelta, matrices, vertexConsumers, light);

        float rawRadius = entity.getRadius();
        float radius = Math.max(0.35f, rawRadius * 0.6f);
        String particle = entity.getParticleType();
        String model = entity.getModelType();
        float age = entity.age + tickDelta;

        matrices.push();
        matrices.translate(0, entity.getHeight() / 2.0, 0);

        if ("rasengan".equals(model) || "rasengan".equals(particle)) {
            renderRasengan(matrices, vertexConsumers, radius, age, light);
        } else {
            int[] colors = getColors(particle);
            int innerColor = colors[0];
            int outerColor = colors[1];

            float spinSpeed = getSpinSpeed(particle);
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * spinSpeed));
            if ("fire".equals(particle) || "flame".equals(particle)) {
                float pulse = 1.0f + MathHelper.sin(age * 0.3f) * 0.1f;
                radius *= pulse;
            }

            renderCrossSphere(matrices, vertexConsumers, radius, innerColor, light, false);
            renderCrossSphere(matrices, vertexConsumers, radius * 1.5f, outerColor, light, true);
        }

        matrices.pop();
    }

    private float getSpinSpeed(String particle) {
        return switch (particle) {
            case "wind" -> 25.0f;
            case "lightning" -> 30.0f;
            case "fire", "flame" -> 10.0f;
            case "water" -> 8.0f;
            default -> 12.0f;
        };
    }

    private int[] getColors(String particle) {
        return switch (particle) {
            case "fire", "flame" -> new int[]{0xFFFF6600, 0x88FF2200};
            case "water" -> new int[]{0xFF2288FF, 0x880044FF};
            case "lightning" -> new int[]{0xFFFFFF44, 0x88FFFF00};
            case "wind" -> new int[]{0xFFCCFFCC, 0x88AAFFAA};
            case "earth" -> new int[]{0xFF996633, 0x88553311};
            case "smoke" -> new int[]{0xFF888888, 0x88444444};
            default -> new int[]{0xFFFF6600, 0x88FF2200};
        };
    }

    private void renderCrossSphere(MatrixStack matrices, VertexConsumerProvider vc,
                                    float radius, int color, int light, boolean isGlow) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(WHITE_TEXTURE));
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        if (a < 0.01f) a = 1.0f;

        for (int i = 0; i < 3; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(i * 60f));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitDoubleSidedQuad(consumer, m,
                    -radius, -radius, 0, radius, -radius, 0, radius, radius, 0, -radius, radius, 0,
                    r, g, b, a, light);
            matrices.pop();
        }

        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitDoubleSidedQuad(consumer, mH,
                -radius, -radius, 0, radius, -radius, 0, radius, radius, 0, -radius, radius, 0,
                r, g, b, a, light);
        matrices.pop();
    }

    private void renderRasengan(MatrixStack matrices, VertexConsumerProvider vc,
                                 float radius, float age, int light) {
        renderCrossSphere(matrices, vc, radius, 0xFF4499FF, light, false);

        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * 25f));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(15f));
        renderRing(matrices, vc, radius * 1.3f, radius * 0.12f, 0xCCFFFFFF, light);
        matrices.pop();

        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(-age * 18f));
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(60f));
        renderRing(matrices, vc, radius * 1.5f, radius * 0.08f, 0xCC88CCFF, light);
        matrices.pop();

        renderCrossSphere(matrices, vc, radius * 1.8f, 0x4488CCFF, light, true);
    }

    private void renderRing(MatrixStack matrices, VertexConsumerProvider vc,
                            float majorRadius, float thickness, int color, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(WHITE_TEXTURE));
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        if (a < 0.01f) a = 1.0f;

        int segments = 20;
        Matrix4f m = matrices.peek().getPositionMatrix();
        for (int i = 0; i < segments; i++) {
            float a1 = (float) (i * 2 * Math.PI / segments);
            float a2 = (float) ((i + 1) * 2 * Math.PI / segments);
            float x1 = MathHelper.cos(a1) * majorRadius;
            float z1 = MathHelper.sin(a1) * majorRadius;
            float x2 = MathHelper.cos(a2) * majorRadius;
            float z2 = MathHelper.sin(a2) * majorRadius;
            float ix1 = MathHelper.cos(a1) * (majorRadius - thickness);
            float iz1 = MathHelper.sin(a1) * (majorRadius - thickness);
            float ix2 = MathHelper.cos(a2) * (majorRadius - thickness);
            float iz2 = MathHelper.sin(a2) * (majorRadius - thickness);

            emitDoubleSidedQuad(consumer, m, x1, thickness, z1, x2, thickness, z2, ix2, thickness, iz2, ix1, thickness, iz1, r, g, b, a, light);
            emitDoubleSidedQuad(consumer, m, ix1, -thickness, iz1, ix2, -thickness, iz2, x2, -thickness, z2, x1, -thickness, z1, r, g, b, a, light);
        }
    }

    private void emitDoubleSidedQuad(VertexConsumer consumer, Matrix4f matrix,
                                      float x1, float y1, float z1, float x2, float y2, float z2,
                                      float x3, float y3, float z3, float x4, float y4, float z4,
                                      float r, float g, float b, float a, int light) {
        vertex(consumer, matrix, x1, y1, z1, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 1, r, g, b, a, light);
        
        vertex(consumer, matrix, x4, y4, z4, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 0, 0, r, g, b, a, light);
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix,
                        float x, float y, float z, float u, float v,
                        float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z)
                .color(r, g, b, a)
                .texture(u, v)
                .overlay(OverlayTexture.DEFAULT_UV)
                .light(light)
                .normal(0, 1, 0)
                .next();
    }

    @Override
    public Identifier getTexture(NinjaProjectileEntity entity) {
        return WHITE_TEXTURE;
    }
}