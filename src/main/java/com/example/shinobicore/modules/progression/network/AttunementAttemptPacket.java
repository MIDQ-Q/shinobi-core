package com.example.shinobicore.modules.progression.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.service.AttunementService;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

public final class AttunementAttemptPacket {
    public static final Identifier ID =
        new Identifier("shinobicore", "progression_attunement_attempt");

    private AttunementAttemptPacket() {}

    public static void sendToServer(String elementId, boolean miniGameSuccess) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(elementId);
        buf.writeBoolean(miniGameSuccess);
        ClientPlayNetworking.send(ID, buf);
    }

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
            final String elementId = buf.readString();
            final boolean miniGameSuccess = buf.readBoolean();

            server.execute(() -> handle(player, elementId, miniGameSuccess));
        });
        ShinobiLogger.module("progression", "Registered C2S packet: " + ID);
    }

    private static void handle(ServerPlayerEntity player, String elementId, boolean success) {
        if (player == null || elementId == null) return;
        AttunementService.attemptAttunement(player, elementId, success);
    }
}