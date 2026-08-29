package com.example.shinobicore.client.vfx.particles;

import com.example.shinobicore.client.render.ShaderCompatibilityManager;
import com.example.shinobicore.client.vfx.VoxelPerformanceOptimizer;
import com.example.shinobicore.client.vfx.VfxBudget;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import org.joml.Matrix4f;
import java.util.ArrayList;
import java.util.List;

/**
 * S5-05: Pooled particle manager. No entity per particle.
 * All particles rendered in a single draw call via VertexConsumer.
 * Respects VfxBudget limits and ShaderCompatibilityManager particle limits.
 */
public class VoxelParticleManager {
    private static final List<VoxelParticle> pool = new ArrayList<>();
    private static final List<VoxelParticle> active = new ArrayList<>();
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    static {
        for (int i = 0; i < 400; i++) pool.add(new VoxelParticle());
    }

    private static int getMaxParticles() {
        return ShaderCompatibilityManager.getParticleLimit();
    }

    /** Spawn a single particle. Returns false if budget exceeded. */
    public static boolean spawn(float x, float y, float z,
                                float vx, float vy, float vz,
                                float r, float g, float b, float a,
                                float size, int life, boolean emissive) {
        if (active.size() >= getMaxParticles()) return false;
        if (!VfxBudget.canSpawn()) return false;
        VoxelParticle p = null;
        for (VoxelParticle candidate : pool) {
            if (!candidate.isAlive()) { p = candidate; break; }
        }
        if (p == null) return false;
        p.init(x, y, z, vx, vy, vz, r, g, b, a, size, life, emissive);
        active.add(p);
        return true;
    }

    /** Spawn a burst of particles. */
    public static void spawnBurst(float x, float y, float z, int count,
                                  float r, float g, float b, float a,
                                  float size, int life, boolean emissive, float spread) {
        int adjusted = Math.max(1, (int)(count * VoxelPerformanceOptimizer.getQualityMultiplier()));
        for (int i = 0; i < adjusted; i++) {
            float vx = (float)(Math.random() - 0.5) * spread;
            float vy = (float)(Math.random() - 0.5) * spread;
            float vz = (float)(Math.random() - 0.5) * spread;
            spawn(x, y, z, vx, vy, vz, r, g, b, a, size, life, emissive);
        }
    }

    /** Update all active particles. Called every client tick. */
    public static void update() {
        for (int i = active.size() - 1; i >= 0; i--) {
            VoxelParticle p = active.get(i);
            p.update();
            if (!p.isAlive()) {
                active.remove(i);
            }
        }
    }

    /** Render all active particles in one draw call. */
    public static void render(MatrixStack matrices, VertexConsumerProvider vc) {
        if (active.isEmpty()) return;
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        net.minecraft.util.math.Vec3d camPos = client.player.getPos();
        VertexConsumer consumer = vc.getBuffer(ShaderCompatibilityManager.getVfxLayer(TEX));
        Matrix4f m = matrices.peek().getPositionMatrix();

        for (VoxelParticle p : active) {
            float alpha = p.getAlpha();
            if (alpha <= 0.01f) continue;

            double dx = p.x - camPos.x;
            double dy = p.y - camPos.y;
            double dz = p.z - camPos.z;
            if (dx * dx + dy * dy + dz * dz > 4096) continue;

            float s = p.getSize();
            int light = p.emissive ? 0xF000F0 : 15728640;

            consumer.vertex(m, (float)dx - s, (float)dy - s, (float)dz)
                .color(p.r, p.g, p.b, alpha)
                .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
                .light(light).normal(0, 1, 0).next();
            consumer.vertex(m, (float)dx + s, (float)dy - s, (float)dz)
                .color(p.r, p.g, p.b, alpha)
                .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
                .light(light).normal(0, 1, 0).next();
            consumer.vertex(m, (float)dx + s, (float)dy + s, (float)dz)
                .color(p.r, p.g, p.b, alpha)
                .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
                .light(light).normal(0, 1, 0).next();
            consumer.vertex(m, (float)dx - s, (float)dy + s, (float)dz)
                .color(p.r, p.g, p.b, alpha)
                .texture(0, 0).overlay(OverlayTexture.DEFAULT_UV)
                .light(light).normal(0, 1, 0).next();
        }
    }

    /** Get active particle count (for debug overlay). */
    public static int getActiveCount() { return active.size(); }

    /** Clear all particles (on disconnect). */
    public static void clear() {
        active.clear();
        for (VoxelParticle p : pool) p.reset();
    }
}