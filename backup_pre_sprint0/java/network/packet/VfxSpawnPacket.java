package com.example.shinobicore.network.packet;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

/**
 * VFX spawn packet (server -> client).
 * HLD: Section 1.2
 * CRITICAL: Read buf BEFORE client.execute()!
 */
public class VfxSpawnPacket {
    public static final Identifier ID = new Identifier("shinobicore", "vfx_spawn");

    public static void send(ServerPlayerEntity player, int vfxType, double x, double y, double z) {
        if (player == null) return;
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(vfxType);
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        ServerPlayNetworking.send(player, ID, buf);
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(ID, (client, handler, buf, sender) -> {
            final int vfxType = buf.readInt();
            final double x = buf.readDouble();
            final double y = buf.readDouble();
            final double z = buf.readDouble();
            client.execute(() -> {
                ShinobiCore.LOGGER.debug("VFX spawn: type=" + vfxType + " pos=" + x + "," + y + "," + z);
            });
        });
    }
}