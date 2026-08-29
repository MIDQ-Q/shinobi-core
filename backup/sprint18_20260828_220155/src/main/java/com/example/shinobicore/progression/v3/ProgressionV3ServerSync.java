// SHINOBICORE:SPRINT15:FILE
package com.example.shinobicore.progression.v3;

import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

/**
 * SPRINT 15 server-to-client progression sync.
 */
public final class ProgressionV3ServerSync {
    public static final Identifier ID =
            new Identifier("shinobicore", "progression_v3_sync");

    private ProgressionV3ServerSync() {}

    public static boolean send(ServerPlayerEntity player, ProgressionV3.Data data) {
        if (player == null || data == null) {
            return false;
        }

        if (!ServerPlayNetworking.canSend(player, ID)) {
            return false;
        }

        PacketByteBuf buf = PacketByteBufs.create();

        buf.writeInt(data.level);
        buf.writeInt(data.xp);
        buf.writeInt(data.sp);

        ServerPlayNetworking.send(player, ID, buf);

        return true;
    }
}