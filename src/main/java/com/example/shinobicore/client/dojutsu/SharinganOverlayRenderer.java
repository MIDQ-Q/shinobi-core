package com.example.shinobicore.client.dojutsu;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * Sharingan overlay renderer.
 * Spawns red particles orbiting around the player's head
 * when Sharingan is active. Particle count depends on stage.
 */
public class SharinganOverlayRenderer {
    private static int tickCounter = 0;
    private static int particleCount = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(SharinganOverlayRenderer::tick);
    }

    public static void setParticleCount(int count) {
        particleCount = count;
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null || client.player == null) return;
        if (particleCount <= 0) return;

        tickCounter++;
        if (tickCounter % 3 != 0) return;

        ClientPlayerEntity player = client.player;
        Vec3d headPos = player.getEyePos();
        float radius = 0.4f;
        float speed = 0.03f;
        int count = Math.min(particleCount, 4);

        for (int i = 0; i < count; i++) {
            float angle = tickCounter * 0.15f + ((float) i / (float) count) * (float) (Math.PI * 2.0);
            float y = (float) headPos.y + (float) Math.sin(tickCounter * 0.1f + i) * 0.2f;
            double x = headPos.x + Math.cos(angle) * radius;
            double z = headPos.z + Math.sin(angle) * radius;

            DustParticleEffect effect = new DustParticleEffect(
                new Vector3f(1.0f, 0.1f, 0.1f), 0.6f);
            client.world.addParticle(effect, x, y, z,
                Math.cos(angle) * speed, 0.01, Math.sin(angle) * speed);
        }
    }
}