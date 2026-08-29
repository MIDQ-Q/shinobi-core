package com.example.shinobicore.network.packet;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/**
 * Cast jutsu packet (client -> server).
 * HLD: Section 1.2
 * CRITICAL: Read buf BEFORE server.execute()!
 */
public class CastJutsuPacket {
    public static final Identifier ID = new Identifier("shinobicore", "cast_jutsu");

    public static void send(String jutsuId) {
        if (jutsuId == null || jutsuId.isEmpty()) return;
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeString(jutsuId);
        ClientPlayNetworking.send(ID, buf);
    }

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
            final String jutsuId = buf.readString();
            server.execute(() -> {
                ShinobiCore.LOGGER.info("Cast request from " + player.getName().getString() + ": " + jutsuId);
            });
        });
    }
}