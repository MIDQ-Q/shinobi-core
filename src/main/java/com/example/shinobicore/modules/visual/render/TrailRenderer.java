package com.example.shinobicore.modules.visual.render;

import com.example.shinobicore.modules.visual.culling.EffectCullingService;
import com.example.shinobicore.modules.visual.pool.TrailPool;
import com.example.shinobicore.modules.visual.pool.TrailPool.PooledTrail;
import com.mojang.blaze3d.systems.RenderSystem;
import net.minecraft.client.render.*;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import org.joml.Matrix4f;

public final class TrailRenderer {
    private static final Identifier TRAIL_TEXTURE = new Identifier("minecraft", "textures/particle/generic.png");

    public static void render(MatrixStack matrices, VertexConsumerProvider consumers, Vec3d cameraPos) {
        int activeCount = TrailPool.getActiveCount();
        if (activeCount == 0) return;

        RenderSystem.setShaderTexture(0, TRAIL_TEXTURE);
        RenderSystem.setShader(GameRenderer::getPositionTexColorProgram);
        RenderSystem.enableBlend();
        RenderSystem.defaultBlendFunc();

        VertexConsumer vertexConsumer = consumers.getBuffer(RenderLayer.getEntityTranslucent(TRAIL_TEXTURE));
        Matrix4f modelMatrix = matrices.peek().getPositionMatrix();

        for (int i = 0; i < activeCount; i++) {
            PooledTrail t = TrailPool.get(i);

            if (!EffectCullingService.shouldRenderEffect(t.startX, t.startY, t.startZ)) continue;

            float sx = t.startX - (float)cameraPos.x;
            float sy = t.startY - (float)cameraPos.y;
            float sz = t.startZ - (float)cameraPos.z;
            float ex = t.endX - (float)cameraPos.x;
            float ey = t.endY - (float)cameraPos.y;
            float ez = t.endZ - (float)cameraPos.z;

            float lifePercent = (float) t.age / (float) t.lifetime;
            float alpha = Math.max(0.0f, 1.0f - lifePercent);

            float r = ((t.color >> 16) & 0xFF) / 255.0f;
            float g = ((t.color >> 8) & 0xFF) / 255.0f;
            float b = (t.color & 0xFF) / 255.0f;
            float a = ((t.color >> 24) & 0xFF) / 255.0f * alpha;

            // Draw a simple line segment (2 vertices)
            // For a proper ribbon trail, we would store an array of points and draw a strip.
            vertexConsumer.vertex(modelMatrix, sx, sy, sz).color(r, g, b, a).texture(0.0f, 0.0f).light(15728880).next();
            vertexConsumer.vertex(modelMatrix, ex, ey, ez).color(r, g, b, a).texture(1.0f, 1.0f).light(15728880).next();
        }

        RenderSystem.disableBlend();
    }
}