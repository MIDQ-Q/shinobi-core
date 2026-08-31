package com.example.shinobicore.modules.progression.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

public final class LevelUpPacket {
    public static final Identifier ID =
        new Identifier("shinobicore", "progression_level_up");

    private LevelUpPacket() {}

    public static void sendTo(ServerPlayerEntity player, int newLevel) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(newLevel);
        ServerPlayNetworking.send(player, ID, buf);
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(ID, (client, handler, buf, sender) -> {
            final int newLevel = buf.readInt();

            client.execute(() -> {
                // Client can play level-up animation/sound here
                ShinobiLogger.module("progression",
                    "Client received level-up: " + newLevel);
            });
        });
        ShinobiLogger.module("progression", "Registered S2C packet: " + ID);
    }
}