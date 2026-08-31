package com.example.shinobicore.modules.jutsu.network;

import com.example.shinobicore.modules.jutsu.slot.JutsuSlotService;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayNetworkHandler;
import net.minecraft.server.network.ServerPlayerEntity;

public final class JutsuSlotChangePacket {
    public static void handle(MinecraftServer server, ServerPlayerEntity player, ServerPlayNetworkHandler handler, PacketByteBuf buf, PacketSender responseSender) {
        // STEP 1: Read ALL data from buffer FIRST
        final int action = buf.readInt(); // 0 = select, 1 = assign
        final int slotIndex = buf.readInt();
        final String jutsuId = action == 1 ? buf.readString(64) : null;

        // STEP 2: Execute on server thread
        server.execute(() -> {
            if (action == 0) {
                JutsuSlotService.selectSlot(player, slotIndex);
            } else if (action == 1 && jutsuId != null) {
                JutsuSlotService.assignJutsu(player, slotIndex, jutsuId);
            }
        });
    }
}