package com.example.shinobicore.network;

import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public record MeditatePacket(boolean start) {
    public static final Identifier ID = new Identifier("shinobicore", "meditate");

    public void write(PacketByteBuf buf) {
        buf.writeBoolean(start);
    }

    public static MeditatePacket read(PacketByteBuf buf) {
        return new MeditatePacket(buf.readBoolean());
    }
}