package com.example.shinobicore.network.packet;

import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public class BlockPacket {
    public static final Identifier ID = new Identifier("shinobicore", "block_state_v2");

    public static void send(boolean blocking) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeBoolean(blocking);
        ClientPlayNetworking.send(ID, buf);
    }
}