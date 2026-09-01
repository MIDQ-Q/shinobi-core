package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class ChakraAuraVisual {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraAuraVisual::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null || client.player == null) return;
        tickCounter++;

        boolean chakraOn = ClientNinjaStateHolder.get().isChakraMode() && ChakraHudRenderer.currentChakra > 0;
        if (!chakraOn) return;

        float chakraRatio = ChakraHudRenderer.maxChakra > 0
            ? ChakraHudRenderer.currentChakra / ChakraHudRenderer.maxChakra : 0;

        boolean flicker = chakraRatio < 0.25f;
        if (flicker && (tickCounter % 8 > 4)) return;

        Vec3d pos = client.player.getPos();
        float pulse = 0.7f + 0.3f * (float) Math.sin(tickCounter * 0.15);

        int flameCount = Math.max(1, (int) (2 * pulse));
        for (int i = 0; i < flameCount; i++) {
            double angle = tickCounter * 0.1 + i * Math.PI * 2 / flameCount;
            double r = 0.35;
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                pos.x + Math.cos(angle) * r,
                pos.y + 0.1,
                pos.z + Math.sin(angle) * r,
                (Math.random() - 0.5) * 0.01,
                0.03,
                (Math.random() - 0.5) * 0.01);
        }

        if (tickCounter % 3 == 0) {
            double angle = Math.random() * Math.PI * 2;
            double r = 0.3 + Math.random() * 0.3;
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                pos.x + Math.cos(angle) * r,
                pos.y + 0.5 + Math.random() * 1.0,
                pos.z + Math.sin(angle) * r,
                0, 0.05, 0);
        }

        if (tickCounter % 5 == 0 && Math.random() < 0.5 * pulse) {
            client.world.addParticle(ParticleTypes.ENCHANT,
                pos.x + (Math.random() - 0.5) * 0.8,
                pos.y + 0.5 + Math.random() * 1.2,
                pos.z + (Math.random() - 0.5) * 0.8,
                0, 0.01, 0);
        }
    }
}