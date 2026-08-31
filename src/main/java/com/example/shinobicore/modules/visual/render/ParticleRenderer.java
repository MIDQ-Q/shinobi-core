package com.example.shinobicore.modules.visual.render;

import net.minecraft.client.MinecraftClient;

import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.example.shinobicore.modules.visual.culling.EffectCullingService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.pool.ParticlePool.PooledParticle;
import com.mojang.blaze3d.systems.RenderSystem;
import net.minecraft.client.render.*;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import org.joml.Matrix4f;

public final class ParticleRenderer {
    // Pre-defined texture for particles (replace with actual mod texture later)
    private static final Identifier PARTICLE_TEXTURE = new Identifier("minecraft", "textures/particle/generic.png");

    public static void render(MatrixStack matrices, VertexConsumerProvider consumers, Vec3d cameraPos, float tickDelta) {
        int activeCount = ParticlePool.getActiveCount();
        if (activeCount == 0) return;

        RenderSystem.setShaderTexture(0, PARTICLE_TEXTURE);
        RenderSystem.setShader(GameRenderer::getPositionTexProgram);
        RenderSystem.enableBlend();
        RenderSystem.defaultBlendFunc();

        VertexConsumer vertexConsumer = consumers.getBuffer(RenderLayer.getEntityTranslucent(PARTICLE_TEXTURE));
        Matrix4f modelMatrix = matrices.peek().getPositionMatrix();

        for (int i = 0; i < activeCount; i++) {
            PooledParticle p = ParticlePool.get(i);
            
            // Culling check (Zero-allocation: pass raw floats)
            if (!EffectCullingService.shouldRenderEffect(p.x, p.y, p.z)) continue;

            // Interpolated position relative to camera
            float px = p.x - (float)cameraPos.x;
            float py = p.y - (float)cameraPos.y;
            float pz = p.z - (float)cameraPos.z;

            // Alpha fade-out based on age
            float lifePercent = (float) p.age / (float) p.lifetime;
            float alpha = MathHelper.clamp(1.0f - lifePercent, 0.0f, 1.0f);
            if (alpha <= 0.01f) continue;

            // Extract ARGB
            float r = ((p.color >> 16) & 0xFF) / 255.0f;
            float g = ((p.color >> 8) & 0xFF) / 255.0f;
            float b = (p.color & 0xFF) / 255.0f;
            float a = ((p.color >> 24) & 0xFF) / 255.0f * alpha;

            // Simple billboard size
            float size = 0.15f;

            // Draw Quad (Facing camera is handled by Minecraft's particle render layer if we use standard matrices,
            // but for custom world render, we draw a flat quad. For true billboard, we'd multiply by camera rotation).
            vertexConsumer.vertex(modelMatrix, px - size, py + size, pz).color(r, g, b, a).texture(0.0f, 0.0f).light(15728880).next();
            vertexConsumer.vertex(modelMatrix, px + size, py + size, pz).color(r, g, b, a).texture(1.0f, 0.0f).light(15728880).next();
            vertexConsumer.vertex(modelMatrix, px + size, py - size, pz).color(r, g, b, a).texture(1.0f, 1.0f).light(15728880).next();
            vertexConsumer.vertex(modelMatrix, px - size, py - size, pz).color(r, g, b, a).texture(0.0f, 1.0f).light(15728880).next();
        }

        RenderSystem.disableBlend();
    }
}