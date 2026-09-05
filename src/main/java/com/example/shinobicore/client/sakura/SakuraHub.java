package com.example.shinobicore.client.sakura;

import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;

public class SakuraHub {
    public static int requestedTab = 0;

    public static void open(int tab) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        requestedTab = tab;
        ClientPlayNetworking.send(SakuraNetwork.OPEN_ID, new PacketByteBuf(Unpooled.buffer()));
    }

    public static void register() {
        ClientTickEvents.START_CLIENT_TICK.register(client -> {
            if (client.player == null || client.currentScreen != null) return;
            if (client.player.isCreative() || client.player.isSpectator()) return;
            if (client.options.inventoryKey.wasPressed()) {
                open(3);
            }
        });
    }
}