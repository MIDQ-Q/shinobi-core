package com.example.shinobicore.network.packet;

import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.minecraft.util.Identifier;

public class ChakraModePacket {
    public static final Identifier ID = new Identifier("shinobicore", "chakra_mode");

    public static void send() {
        ClientPlayNetworking.send(ID, PacketByteBufs.empty());
    }
}