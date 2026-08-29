// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.progression.v3;

import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayNetworkHandler;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

/**
 * SPRINT 18 server handler for progression C2S packets.
 */
public final class ProgressionV3ServerHandler {
    public static final Identifier SPEND_STAT_ID =
            new Identifier("shinobicore", "progression_v3_spend_stat");

    private static boolean registered = false;

    private ProgressionV3ServerHandler() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

ServerPlayNetworking.registerGlobalReceiver(
    SPEND_STAT_ID,
    (MinecraftServer server,
     ServerPlayerEntity player,
     ServerPlayNetworkHandler handler,
     PacketByteBuf buf,
     PacketSender responseSender) -> {
        String stat = buf.readString();
        server.execute(() -> ProgressionV3.spendSpOnStat(player, stat));
    }
                
        );
    }
}