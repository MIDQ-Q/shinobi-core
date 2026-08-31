package com.example.shinobicore.modules.progression.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.service.XpSourceService;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

public final class MiniGameResultPacket {
    public static final Identifier ID =
        new Identifier("shinobicore", "progression_minigame_result");

    private MiniGameResultPacket() {}

    public static void sendToServer(String gameId, boolean success) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(gameId);
        buf.writeBoolean(success);
        ClientPlayNetworking.send(ID, buf);
    }

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
            final String gameId = buf.readString();
            final boolean success = buf.readBoolean();

            server.execute(() -> handle(player, gameId, success));
        });
        ShinobiLogger.module("progression", "Registered C2S packet: " + ID);
    }

    private static void handle(ServerPlayerEntity player, String gameId, boolean success) {
        if (player == null || gameId == null) return;
        if (!success) return;

        com.example.shinobicore.modules.progression.data.MiniGameRegistry.get(gameId).ifPresent(def -> {
            int xp = def.rewardXp();
            if (xp > 0) {
                XpSourceService.awardXp(player, xp, "minigame:" + gameId);
            }
            ShinobiLogger.module("progression",
                player.getName().getString() + " completed minigame: " + gameId);
        });
    }
}