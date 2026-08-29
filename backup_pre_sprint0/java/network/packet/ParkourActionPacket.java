package com.example.shinobicore.network.packet;

import com.example.shinobicore.parkour.ParkourServerHandler;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public class ParkourActionPacket {
    public static final Identifier ID = new Identifier("shinobicore", "parkour_action_v2");

    public static void send(int actionOrdinal, float directionYaw) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(actionOrdinal);
        buf.writeFloat(directionYaw);
        ClientPlayNetworking.send(ID, buf);
    }

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
            final int action = buf.readInt();
            final float yaw = buf.readFloat();
            
            server.execute(() -> {
                ParkourServerHandler.handleAction(player, action, yaw);
            });
        });
    }
}