package com.example.shinobicore.client.render;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.util.ColorHelper;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import org.joml.Matrix3f;
import org.joml.Matrix4f;

/**
 * Renders the projectile as a colored camera-facing billboard.
 * Color comes from JSON visuals.color (HLD 2.4).
 * Yarn 1.20.1: EntityVertexConsumer requires .overlay() in the chain.
 */
public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {

    private static final Identifier TEXTURE =
        new Identifier("shinobicore", "textures/entity/projectile_white.png");

    public NinjaProjectileRenderer(EntityRendererFactory.Context context) {
        super(context);
    }

    @Override
    public Identifier getTexture(NinjaProjectileEntity entity) {
        return TEXTURE;
    }

    @Override
    public void render(NinjaProjectileEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light) {
        matrices.push();
        matrices.multiply(this.dispatcher.getRotation());

        float size = 0.6f;
        matrices.scale(size, size, size);

        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(TEXTURE));
        Matrix4f model = matrices.peek().getPositionMatrix();
        Matrix3f normalMatrix = matrices.peek().getNormalMatrix();

        int color = entity.getColor();
        float r = ColorHelper.red(color);
        float g = ColorHelper.green(color);
        float b = ColorHelper.blue(color);
        int overlay = OverlayTexture.DEFAULT_UV;

        vc.vertex(model, -0.5f, -0.5f, 0.0f).color(r, g, b, 0.9f)
            .texture(0.0f, 1.0f).overlay(overlay).light(light).normal(normalMatrix, 0.0f, 1.0f, 0.0f).next();
        vc.vertex(model, -0.5f, 0.5f, 0.0f).color(r, g, b, 0.9f)
            .texture(0.0f, 0.0f).overlay(overlay).light(light).normal(normalMatrix, 0.0f, 1.0f, 0.0f).next();
        vc.vertex(model, 0.5f, 0.5f, 0.0f).color(r, g, b, 0.9f)
            .texture(1.0f, 0.0f).overlay(overlay).light(light).normal(normalMatrix, 0.0f, 1.0f, 0.0f).next();
        vc.vertex(model, 0.5f, -0.5f, 0.0f).color(r, g, b, 0.9f)
            .texture(1.0f, 1.0f).overlay(overlay).light(light).normal(normalMatrix, 0.0f, 1.0f, 0.0f).next();

        matrices.pop();
        super.render(entity, yaw, tickDelta, matrices, vertexConsumers, light);
    }
}