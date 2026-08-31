// SHINOBI_V3_CLIENT_VFX
package com.example.shinobicore.network.packet;

import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.PlayerLookup;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

public final class VfxSpawnPacket {
    public static final Identifier ID = new Identifier("shinobicore", "vfx_spawn_v3");

    private VfxSpawnPacket() {
    }

    public static void send(ServerPlayerEntity player, int vfxType, double x, double y, double z) {
        send(player, vfxType, x, y, z, 1.0f);
    }

    public static void send(ServerPlayerEntity player, int vfxType, double x, double y, double z, float scale) {
        if (player == null) {
            return;
        }

        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeVarInt(vfxType);
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        buf.writeFloat(scale);

        ServerPlayNetworking.send(player, ID, buf);
    }

    public static void broadcast(ServerPlayerEntity source, int vfxType, double x, double y, double z) {
        broadcast(source, vfxType, x, y, z, 1.0f);
    }

    public static void broadcast(ServerPlayerEntity source, int vfxType, double x, double y, double z, float scale) {
        if (source == null) {
            return;
        }

        for (ServerPlayerEntity target : PlayerLookup.tracking(source)) {
            if (target != source) {
                send(target, vfxType, x, y, z, scale);
            }
        }

        send(source, vfxType, x, y, z, scale);
    }

    /**
     * Deprecated no-op kept for source compatibility with old entrypoints.
     * Client registration is done by VfxSpawnPacketClient from VfxClientBootstrap.
     */
    @Deprecated
    public static void registerClient() {
    }
}