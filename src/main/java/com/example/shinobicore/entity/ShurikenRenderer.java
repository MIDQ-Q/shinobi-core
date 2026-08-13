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
        if (!entity.isStuck()) {
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees((entity.getAge() + tickDelta) * 25f));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        }
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        float s = 0.22f;
        for (int q = 0; q < 2; q++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(q * 90f));
            Matrix4f m = matrices.peek().getPositionMatrix();
            vertex(consumer, m, -s, 0, -s, light); vertex(consumer, m, -s, 0, s, light);
            vertex(consumer, m, s, 0, s, light);   vertex(consumer, m, s, 0, -s, light);
            matrices.pop();
        }
        matrices.pop();
    }
    private void vertex(VertexConsumer c, Matrix4f m, float x, float y, float z, int light) {
        c.vertex(m, x, y, z).color(0.75f, 0.75f, 0.78f, 1f).texture(0, 0)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
    @Override public Identifier getTexture(ShurikenEntity entity) { return TEX; }
}