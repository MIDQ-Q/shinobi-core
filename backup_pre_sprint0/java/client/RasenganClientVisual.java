package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

public class RasenganClientVisual {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(RasenganClientVisual::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;
        tickCounter++;

        if (RasenganClientState.charging) {
            spawnChargingParticles(client, player, RasenganClientState.chargeProgress);
        }
        if (RasenganClientState.ready) {
            spawnReadyParticles(client, player);
        }
    }

    private static void spawnChargingParticles(MinecraftClient client, ClientPlayerEntity player, float progress) {
        if (tickCounter % 2 != 0) return;
        
        Vec3d handPos = getHandPosition(player);
        float radius = 0.12f + progress * 0.23f;
        int count = (int)(1 + progress * 3); 
        
        for (int i = 0; i < count; i++) {
            float theta = (float)Math.random() * (float)(Math.PI * 2);
            float phi = (float)Math.acos(2 * Math.random() - 1);
            double x = handPos.x + radius * Math.sin(phi) * Math.cos(theta);
            double y = handPos.y + radius * Math.cos(phi);
            double z = handPos.z + radius * Math.sin(phi) * Math.sin(theta);
            
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME, x, y, z,
                (Math.random() - 0.5) * 0.02, (Math.random() - 0.5) * 0.02, (Math.random() - 0.5) * 0.02);
        }

        if (progress > 0.5f && tickCounter % 4 == 0) {
            client.world.addParticle(ParticleTypes.CRIT,
                handPos.x + (Math.random() - 0.5) * radius * 1.5,
                handPos.y + (Math.random() - 0.5) * radius * 1.5,
                handPos.z + (Math.random() - 0.5) * radius * 1.5,
                (Math.random() - 0.5) * 0.04, Math.random() * 0.04, (Math.random() - 0.5) * 0.04);
        }
    }

    private static void spawnReadyParticles(MinecraftClient client, ClientPlayerEntity player) {
        if (tickCounter % 2 != 0) return;
        
        Vec3d handPos = getHandPosition(player);
        float radius = 0.35f;
        float rotation = tickCounter * 0.2f;

        for (int i = 0; i < 6; i++) {
            float angle = rotation + (i / 6.0f) * (float)(Math.PI * 2);
            float phi = (float)Math.acos(2 * ((i * 0.618f) % 1.0f) - 1);
            double x = handPos.x + radius * Math.sin(phi) * Math.cos(angle);
            double y = handPos.y + radius * Math.cos(phi);
            double z = handPos.z + radius * Math.sin(phi) * Math.sin(angle);
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME, x, y, z, 0, 0, 0);
        }

        for (int i = 0; i < 3; i++) {
            float t = i / 3.0f;
            float spiralAngle = rotation * 3 + t * (float)(Math.PI * 4);
            double x = handPos.x + radius * 0.7 * Math.cos(spiralAngle);
            double y = handPos.y + (t - 0.5) * radius * 1.2;
            double z = handPos.z + radius * 0.7 * Math.sin(spiralAngle);
            client.world.addParticle(ParticleTypes.END_ROD, x, y, z, 0, 0.01, 0);
        }
    }

    private static Vec3d getHandPosition(ClientPlayerEntity player) {
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        return player.getEyePos().add(look.multiply(0.8)).add(right.multiply(0.4)).add(0, -0.3, 0);
    }
}