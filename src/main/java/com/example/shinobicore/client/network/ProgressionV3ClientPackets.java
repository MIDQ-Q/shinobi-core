// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.client.network;

import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/**
 * SPRINT 18 client-to-server progression packets.
 */
public final class ProgressionV3ClientPackets {
    public static final Identifier SPEND_STAT_ID =
            new Identifier("shinobicore", "progression_v3_spend_stat");

    private ProgressionV3ClientPackets() {}

    public static void sendSpendStat(String stat) {
        if (stat == null || stat.isEmpty()) {
            return;
        }

        if (MinecraftClient.getInstance().player == null) {
            return;
        }

        if (!ClientPlayNetworking.canSend(SPEND_STAT_ID)) {
            return;
        }

        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeString(stat);

        ClientPlayNetworking.send(SPEND_STAT_ID, buf);
    }
}