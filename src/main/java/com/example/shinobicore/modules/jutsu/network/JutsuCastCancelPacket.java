package com.example.shinobicore.modules.jutsu.network;

import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayNetworkHandler;
import net.minecraft.server.network.ServerPlayerEntity;

public final class JutsuCastCancelPacket {
    public static void handle(MinecraftServer server, ServerPlayerEntity player, ServerPlayNetworkHandler handler, PacketByteBuf buf, PacketSender responseSender) {
        // STEP 1: Read ALL data from buffer FIRST
        final String reason = buf.readString(32); // Limit string length for safety

        // STEP 2: Execute on server thread
        server.execute(() -> {
            JutsuCastService.instance().cancelCast(player, reason);
        });
    }
}