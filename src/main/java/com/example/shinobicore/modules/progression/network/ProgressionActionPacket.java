package com.example.shinobicore.modules.progression.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.service.SkillTreeService;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

public final class ProgressionActionPacket {
    public static final Identifier ID = new Identifier("shinobicore", "progression_action");

    public static final int ACTION_UNLOCK_NODE = 1;
    public static final int ACTION_SPEND_SP = 2;

    private ProgressionActionPacket() {}

    public static void sendToServer(int action, String payload) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(action);
        buf.writeString(payload);
        ClientPlayNetworking.send(ID, buf);
    }

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
            final int action = buf.readInt();
            final String payload = buf.readString();

            server.execute(() -> handleAction(player, action, payload));
        });
        ShinobiLogger.module("progression", "Registered C2S packet: " + ID);
    }

    private static void handleAction(ServerPlayerEntity player, int action, String payload) {
        if (player == null || payload == null) return;
        switch (action) {
            case ACTION_UNLOCK_NODE -> {
                boolean success = SkillTreeService.unlockNode(player, payload);
                if (!success) {
                    ShinobiLogger.module("progression", "Player " + player.getName().getString() + " failed to unlock node: " + payload);
                    ProgressionStateSyncPacket.sendTo(player);
                }
            }
            case ACTION_SPEND_SP -> {
            }
            default -> ShinobiLogger.error("progression", "Unknown action ID: " + action, null);
        }
    }
}