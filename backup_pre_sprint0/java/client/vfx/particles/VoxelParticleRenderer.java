package com.example.shinobicore.client.vfx.particles;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderContext;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;

/**
 * S5-05: Registers particle update and render hooks.
 * Update: every client tick via ClientTickEvents.
 * Render: after translucent layer via WorldRenderEvents.
 */
public class VoxelParticleRenderer {

    public static void register() {
        // Update particles every tick
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (client.world == null) return;
            VoxelParticleManager.update();
        });

        // Render particles after world translucent pass
        WorldRenderEvents.AFTER_TRANSLUCENT.register(context -> {
            MatrixStack matrices = context.matrixStack();
            VertexConsumerProvider consumers = context.consumers();
            if (consumers == null) return;
            MinecraftClient client = MinecraftClient.getInstance();
            if (client.player == null || client.world == null) return;
            VoxelParticleManager.render(matrices, consumers);
        });
    }
}