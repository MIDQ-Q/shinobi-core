package com.example.shinobicore.client.network;

import com.example.shinobicore.client.vfx.ClientVfxManager;
import com.example.shinobicore.network.packet.VfxSpawnPacket;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;

public final class VfxSpawnPacketClient {
    private static boolean registered = false;

    private VfxSpawnPacketClient() {
    }

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        ClientPlayNetworking.registerGlobalReceiver(VfxSpawnPacket.ID, (client, handler, buf, sender) -> {
            final int type = buf.readVarInt();
            final double x = buf.readDouble();
            final double y = buf.readDouble();
            final double z = buf.readDouble();
            final float scale = buf.readFloat();

            client.execute(() -> ClientVfxManager.enqueue(type, x, y, z, scale));
        });
    }
}