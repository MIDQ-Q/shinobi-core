// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.progression.v3;

import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

import java.util.Map;

/**
 * SPRINT 18 server-to-client progression sync.
 */
public final class ProgressionV3ServerSync {
    public static final Identifier ID =
            new Identifier("shinobicore", "progression_v3_sync");

    public static final Identifier FULL_ID =
            new Identifier("shinobicore", "progression_v3_full_sync");

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

    public static boolean sendFull(ServerPlayerEntity player, ProgressionV3.Data data) {
        if (player == null || data == null) {
            return false;
        }

        if (!ServerPlayNetworking.canSend(player, FULL_ID)) {
            return false;
        }

        PacketByteBuf buf = PacketByteBufs.create();

        buf.writeInt(data.level);
        buf.writeInt(data.xp);
        buf.writeInt(data.sp);

        buf.writeVarInt(data.statLevels.size());

        for (Map.Entry<String, Integer> entry : data.statLevels.entrySet()) {
            String stat = entry.getKey();
            int statLevel = entry.getValue();
            int statXp = data.statXp.getOrDefault(stat, 0);

            buf.writeString(stat);
            buf.writeVarInt(statLevel);
            buf.writeVarInt(statXp);
        }

        ServerPlayNetworking.send(player, FULL_ID, buf);

        return true;
    }
}