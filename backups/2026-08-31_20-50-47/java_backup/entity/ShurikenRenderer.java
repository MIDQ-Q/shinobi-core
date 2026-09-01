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

public class ShurikenRenderer extends EntityRenderer<ShurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    public ShurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override public void render(ShurikenEntity entity, float yaw, float tickDelta,
            MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();
        matrices.translate(0, 0.25, 0);
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        boolean kunai = entity.getDamage() > 4f;
        if (kunai) {
            if (!entity.isStuck()) matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
            renderKunai(consumer, matrices, light);
        } else {
            if (!entity.isStuck()) {
                matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees((entity.getAge() + tickDelta) * 25f));
                matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
            }
            renderShuriken(consumer, matrices, light);
        }
        matrices.pop();
    }

    private void renderShuriken(VertexConsumer c, MatrixStack matrices, int light) {
        for (int i = 0; i < 4; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(i * 90f));
            Matrix4f m = matrices.peek().getPositionMatrix();
            v(c, m, -0.05f, 0, 0.02f, 0.78f, light);
            v(c, m,  0.05f, 0, 0.02f, 0.78f, light);
            v(c, m,  0.02f, 0, 0.26f, 0.95f, light);
            v(c, m, -0.02f, 0, 0.26f, 0.95f, light);
            v(c, m,  0.05f, 0, 0.02f, 0.78f, light);
            v(c, m, -0.05f, 0, 0.02f, 0.78f, light);
            v(c, m, -0.02f, 0, 0.26f, 0.95f, light);
            v(c, m,  0.02f, 0, 0.26f, 0.95f, light);
            matrices.pop();
        }
        Matrix4f m = matrices.peek().getPositionMatrix();
        v(c, m, -0.045f, 0.001f, -0.045f, 0.25f, light);
        v(c, m,  0.045f, 0.001f, -0.045f, 0.25f, light);
        v(c, m,  0.045f, 0.001f,  0.045f, 0.25f, light);
        v(c, m, -0.045f, 0.001f,  0.045f, 0.25f, light);
    }

    private void renderKunai(VertexConsumer c, MatrixStack matrices, int light) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        // blade diamond (tip / left / inner / right)
        v(c, m, 0, 0.002f, 0.30f, 0.95f, light);
        v(c, m, -0.05f, 0.002f, 0.06f, 0.8f, light);
        v(c, m, 0, 0.002f, 0.02f, 0.7f, light);
        v(c, m, 0.05f, 0.002f, 0.06f, 0.8f, light);
        v(c, m, 0, 0.002f, 0.30f, 0.95f, light);
        v(c, m, 0.05f, 0.002f, 0.06f, 0.8f, light);
        v(c, m, 0, 0.002f, 0.02f, 0.7f, light);
        v(c, m, -0.05f, 0.002f, 0.06f, 0.8f, light);
        // handle
        v(c, m, -0.015f, 0, 0.06f, 0.3f, light);
        v(c, m,  0.015f, 0, 0.06f, 0.3f, light);
        v(c, m,  0.015f, 0, -0.14f, 0.3f, light);
        v(c, m, -0.015f, 0, -0.14f, 0.3f, light);
        v(c, m,  0.015f, 0, 0.06f, 0.3f, light);
        v(c, m, -0.015f, 0, 0.06f, 0.3f, light);
        v(c, m, -0.015f, 0, -0.14f, 0.3f, light);
        v(c, m,  0.015f, 0, -0.14f, 0.3f, light);
        // ring pommel
        v(c, m, -0.035f, 0, -0.14f, 0.5f, light);
        v(c, m,  0.035f, 0, -0.14f, 0.5f, light);
        v(c, m,  0.035f, 0, -0.20f, 0.5f, light);
        v(c, m, -0.035f, 0, -0.20f, 0.5f, light);
    }

    private void v(VertexConsumer c, Matrix4f m, float x, float y, float z, float shade, int light) {
        c.vertex(m, x, y, z).color(shade, shade, shade + 0.03f, 1f).texture(0, 0)
         .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override public Identifier getTexture(ShurikenEntity entity) { return TEX; }
}