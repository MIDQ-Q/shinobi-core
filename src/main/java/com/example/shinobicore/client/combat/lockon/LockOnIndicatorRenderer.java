package com.example.shinobicore.client.combat.lockon;

import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.combat.frenzy.FrenzyClientState;
import com.example.shinobicore.config.ModConfig;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.entity.LivingEntity;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import org.joml.Matrix4f;

/**
 * Combat Pack v1 (1.1.4): маркер цели мягкого наведения.
 * Тонкое кольцо над головой цели (мир-спейс, не трогает рендер сущностей —
 * не конфликтует с GeckoLib/другими модами). Цвет: белый -> оранжевый при
 * атаке -> красный в боевом раже.
 */
public final class LockOnIndicatorRenderer {

    private LockOnIndicatorRenderer() {}

    private static final int FULL_LIGHT = 0x00F000F0;

    public static void register() {
        WorldRenderEvents.AFTER_ENTITIES.register(LockOnIndicatorRenderer::render);
    }

    private static void render(WorldRenderContext ctx) {
        LivingEntity target = SoftLockOnSystem.getTarget();
        float strength = SoftLockOnSystem.getLockStrength();
        if (target == null || strength <= 0.3f) return;
        ModConfig.Combat c = ModConfig.instance.combat;
        if (c == null || !c.lockOnShowIndicator) return;

        MatrixStack ms = ctx.matrixStack();
        Vec3d cam = ctx.camera().getPos();
        Vec3d ring = target.getPos().add(0, target.getHeight() + 0.32, 0).subtract(cam);

        float pulse = 0.75f + 0.25f * MathHelper.sin((float) (System.currentTimeMillis() % 6283) / 1000f * 4f);
        float alpha = MathHelper.clamp(0.30f + 0.45f * strength, 0f, 0.85f) * pulse;

        float r, g, b;
        if (FrenzyClientState.getLevel() >= 2) { r = 1.0f; g = 0.28f; b = 0.22f; }
        else if (TaijutsuClientHandler.isAttacking()) { r = 1.0f; g = 0.62f; b = 0.20f; }
        else { r = 0.95f; g = 0.95f; b = 1.0f; }

        float radius = 0.30f + target.getWidth() * 0.35f;

        ms.push();
        ms.translate(ring.x, ring.y, ring.z);
        Matrix4f m = ms.peek().getPositionMatrix();
        VertexConsumer vc = ctx.consumers().getBuffer(RenderLayer.getLines());

        int segments = 20;
        for (int i = 0; i < segments; i++) {
            double a1 = i * Math.PI * 2.0 / segments;
            double a2 = (i + 1) * Math.PI * 2.0 / segments;
            float x1 = (float) Math.cos(a1) * radius, z1 = (float) Math.sin(a1) * radius;
            float x2 = (float) Math.cos(a2) * radius, z2 = (float) Math.sin(a2) * radius;
            vc.vertex(m, x1, 0f, z1).color(r, g, b, alpha).light(FULL_LIGHT).normal(0, 1, 0).next();
            vc.vertex(m, x2, 0f, z2).color(r, g, b, alpha).light(FULL_LIGHT).normal(0, 1, 0).next();
        }
        // четыре «уголка»-риски по сторонам кольца — читаемость на дистанции
        for (int k = 0; k < 4; k++) {
            double a = k * Math.PI / 2.0 + Math.PI / 4.0;
            float x1 = (float) Math.cos(a) * radius, z1 = (float) Math.sin(a) * radius;
            float x2 = (float) Math.cos(a) * (radius + 0.09f), z2 = (float) Math.sin(a) * (radius + 0.09f);
            vc.vertex(m, x1, 0f, z1).color(r, g, b, alpha * 0.8f).light(FULL_LIGHT).normal(0, 1, 0).next();
            vc.vertex(m, x2, 0f, z2).color(r, g, b, alpha * 0.8f).light(FULL_LIGHT).normal(0, 1, 0).next();
        }
        ms.pop();
    }
}