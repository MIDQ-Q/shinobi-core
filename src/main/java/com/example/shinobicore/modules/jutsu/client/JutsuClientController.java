package com.example.shinobicore.modules.jutsu.client;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ClientNinjaStateHolder;
import com.example.shinobicore.modules.jutsu.network.JutsuPackets;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;
import io.netty.buffer.Unpooled;

/**
 * Handles client-side input for jutsu casting.
 * Reads keybinds, sends cast requests to server.
 */
public final class JutsuClientController {
    private static long lastCastMs = 0;
    private static final long CAST_DEBOUNCE_MS = 250;

    private JutsuClientController() {}

    public static void init() {
        ClientTickEvents.END_CLIENT_TICK.register(JutsuClientController::tick);
        ShinobiCore.LOGGER.info("[JutsuClient] Controller ready.");
    }

    private static void tick(MinecraftClient client) {
        if (client.player == null || client.currentScreen != null) return;

        // Cast A (R key by default)
        if (com.example.shinobicore.client.KeyBindings.CAST_A.wasPressed()) {
            tryCast(client, 0);
        }
        // Cast B (T key by default)
        if (com.example.shinobicore.client.KeyBindings.CAST_B.wasPressed()) {
            tryCast(client, 1);
        }
    }

    private static void tryCast(MinecraftClient client, int set) {
        long now = System.currentTimeMillis();
        if (now - lastCastMs < CAST_DEBOUNCE_MS) return;
        lastCastMs = now;

        String jutsuId = ClientNinjaStateHolder.get().getActiveJutsuId(set);
        if (jutsuId == null || jutsuId.isEmpty()) return;

        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(set);
        buf.writeInt(ClientNinjaStateHolder.get().getActive(set));
        ClientPlayNetworking.send(JutsuPackets.CAST_REQUEST, buf);
    }
}