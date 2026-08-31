package com.example.shinobicore.modules.jutsu.network;

import net.minecraft.server.network.ServerPlayerEntity;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.client.JutsuClientState;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public final class JutsuPackets {
    public static final Identifier CAST_REQUEST = new Identifier("shinobicore", "jutsu_cast_request");
    public static final Identifier CAST_CANCEL = new Identifier("shinobicore", "jutsu_cast_cancel");
    public static final Identifier SLOT_CHANGE = new Identifier("shinobicore", "jutsu_slot_change");
    public static final Identifier STATE_SYNC = new Identifier("shinobicore", "jutsu_state_sync");

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(CAST_REQUEST, JutsuCastRequestPacket::handle);
        ServerPlayNetworking.registerGlobalReceiver(CAST_CANCEL, JutsuCastCancelPacket::handle);
        ServerPlayNetworking.registerGlobalReceiver(SLOT_CHANGE, JutsuSlotChangePacket::handle);
        ShinobiLogger.module("jutsu", "Server packets registered.");
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(STATE_SYNC, (client, handler, buf, responseSender) -> {
            // STEP 1: Read ALL data FIRST
            final boolean isCasting = buf.readBoolean();
            final float progress = buf.readFloat();
            final String phase = buf.readString(32);
            final String jutsuId = buf.readString(64);

            // STEP 2: Execute on client thread
            client.execute(() -> {
                JutsuClientState.updateFromServer(isCasting, progress, phase, jutsuId);
            });
        });
        ShinobiLogger.module("jutsu", "Client packets registered.");
    }
    
    // Helper to send state sync from server to client (to be called in JutsuCastService or Session)
    public static void sendStateSync(ServerPlayerEntity player, boolean isCasting, float progress, String phase, String jutsuId) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeBoolean(isCasting);
        buf.writeFloat(progress);
        buf.writeString(phase);
        buf.writeString(jutsuId);
        ServerPlayNetworking.send(player, STATE_SYNC, buf);
    }
}