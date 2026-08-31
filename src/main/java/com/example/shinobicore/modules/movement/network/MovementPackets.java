package com.example.shinobicore.modules.movement.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.server.MovementServerMirror;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public final class MovementPackets {
    public static final Identifier ACTION_ID = new Identifier("shinobicore", "movement_action");

    private MovementPackets() {}

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ACTION_ID, (server, player, handler, buf, sender) -> {
            // CRITICAL RULE: Read ALL data from buffer FIRST
            final int actionId = buf.readInt();
            final float yaw = buf.readFloat();
            final double vx = buf.readDouble();
            final double vz = buf.readDouble();

            // THEN execute on server thread
            server.execute(() -> {
                try {
                    MovementServerMirror.handleAction(player, actionId, yaw, vx, vz);
                } catch (Exception e) {
                    ShinobiLogger.error("movement", "Failed to handle action packet", e);
                }
            });
        });
        ShinobiLogger.module("movement", "Server packets registered.");
    }

    public static void registerClient() {
        // Client receivers (e.g., state sync from server) go here
        ShinobiLogger.module("movement", "Client packets registered.");
    }

    public static void sendActionToServer(int actionId, float yaw, double vx, double vz) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(actionId);
        buf.writeFloat(yaw);
        buf.writeDouble(vx);
        buf.writeDouble(vz);
        ClientPlayNetworking.send(ACTION_ID, buf);
    }
}