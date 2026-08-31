package com.example.shinobicore.modules.progression.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

public final class StatChangedPacket {
    public static final Identifier ID =
        new Identifier("shinobicore", "progression_stat_changed");

    private StatChangedPacket() {}

    public static void sendTo(ServerPlayerEntity player, String statId, int newLevel) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeString(statId);
        buf.writeInt(newLevel);
        ServerPlayNetworking.send(player, ID, buf);
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(ID, (client, handler, buf, sender) -> {
            final String statId = buf.readString();
            final int newLevel = buf.readInt();

            client.execute(() -> {
                // Client can play stat-change animation here
                ShinobiLogger.module("progression",
                    "Client received stat change: " + statId + " -> " + newLevel);
            });
        });
        ShinobiLogger.module("progression", "Registered S2C packet: " + ID);
    }
}