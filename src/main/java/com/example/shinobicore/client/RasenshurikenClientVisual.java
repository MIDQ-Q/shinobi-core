package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

public class RasenshurikenClientVisual {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(RasenshurikenClientVisual::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;
        tickCounter++;

        if (RasenshurikenClientState.charging || RasenshurikenClientState.ready) {
            // Спавним строго НАД ГОЛОВОЙ (Y + 2.2), чтобы не мешать прицелу
            Vec3d headPos = player.getPos().add(0, 2.2, 0);
            float radius = RasenshurikenClientState.ready ? 1.2f : 0.4f + RasenshurikenClientState.progress * 0.8f;
            
            float rotation = tickCounter * 0.3f;
            int count = RasenshurikenClientState.ready ? 40 : 15;
            
            for (int i = 0; i < count; i++) {
                float angle = rotation + (i / (float) count) * (float)(Math.PI * 2);
                double x = headPos.x + Math.cos(angle) * radius;
                double z = headPos.z + Math.sin(angle) * radius;
                double y = headPos.y + Math.sin(angle * 2 + tickCounter * 0.1) * 0.3;
                
                client.world.addParticle(ParticleTypes.CLOUD, x, y, z, 0, 0, 0);
                if (RasenshurikenClientState.ready) {
                    client.world.addParticle(ParticleTypes.END_ROD, x, y, z, 0, 0.02, 0);
                }
            }
            
            if (RasenshurikenClientState.ready) {
                client.world.addParticle(ParticleTypes.END_ROD, headPos.x, headPos.y, headPos.z, 0, 0.05, 0);
            }
        }
    }
}