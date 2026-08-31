package com.example.shinobicore.modules.jutsu.network;

import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.slot.JutsuSlotService;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayNetworkHandler;
import net.minecraft.server.network.ServerPlayerEntity;

public final class JutsuCastRequestPacket {
    public static void handle(MinecraftServer server, ServerPlayerEntity player, ServerPlayNetworkHandler handler, PacketByteBuf buf, PacketSender responseSender) {
        // STEP 1: Read ALL data from buffer FIRST (CRITICAL RULE)
        final int slot = buf.readInt();
        final long pressTimestampMs = buf.readLong();
        final float yaw = buf.readFloat();
        final float pitch = buf.readFloat();

        // STEP 2: Execute on server thread
        server.execute(() -> {
            String jutsuId = JutsuSlotService.getLoadout(player).getSlot(slot);
            if (jutsuId != null) {
                JutsuCastService.instance().requestCast(player, jutsuId, slot, pressTimestampMs, yaw, pitch);
            }
        });
    }
}