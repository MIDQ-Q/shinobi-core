package com.example.shinobicore.modules.progression.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.client.ProgressionClientState;
import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;

import java.util.Map;
import java.util.Set;

public final class ProgressionStateSyncPacket {
    public static final Identifier ID = new Identifier("shinobicore", "progression_sync");

    private ProgressionStateSyncPacket() {}

    public static void sendTo(ServerPlayerEntity player) {
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            PacketByteBuf buf = PacketByteBufs.create();
            buf.writeInt(comp.getPlayerLevel());
            buf.writeInt(comp.getCurrentXp());
            buf.writeInt(comp.getAvailableSp());

            Set<String> nodes = comp.getUnlockedNodes();
            buf.writeInt(nodes.size());
            for (String node : nodes) buf.writeString(node);

            Set<String> elements = comp.getUnlockedElements();
            buf.writeInt(elements.size());
            for (String el : elements) buf.writeString(el);

            Map<String, Integer> stats = comp.getAllStats();
            buf.writeInt(stats.size());
            for (Map.Entry<String, Integer> e : stats.entrySet()) {
                buf.writeString(e.getKey());
                buf.writeInt(e.getValue());
            }

            Map<String, Integer> bodyStats = comp.getAllBodyStats();
            buf.writeInt(bodyStats.size());
            for (Map.Entry<String, Integer> e : bodyStats.entrySet()) {
                buf.writeString(e.getKey());
                buf.writeInt(e.getValue());
            }

            ServerPlayNetworking.send(player, ID, buf);
        });
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(ID, (client, handler, buf, sender) -> {
            final int level = buf.readInt();
            final int xp = buf.readInt();
            final int sp = buf.readInt();

            final int nodeCount = buf.readInt();
            final String[] nodes = new String[nodeCount];
            for (int i = 0; i < nodeCount; i++) nodes[i] = buf.readString();

            final int elemCount = buf.readInt();
            final String[] elements = new String[elemCount];
            for (int i = 0; i < elemCount; i++) elements[i] = buf.readString();

            final int statCount = buf.readInt();
            final String[] statIds = new String[statCount];
            final int[] statVals = new int[statCount];
            for (int i = 0; i < statCount; i++) {
                statIds[i] = buf.readString();
                statVals[i] = buf.readInt();
            }

            final int bodyCount = buf.readInt();
            final String[] bodyIds = new String[bodyCount];
            final int[] bodyVals = new int[bodyCount];
            for (int i = 0; i < bodyCount; i++) {
                bodyIds[i] = buf.readString();
                bodyVals[i] = buf.readInt();
            }

            client.execute(() -> {
                ProgressionClientState.update(
                    level, xp, sp, nodes, elements,
                    statIds, statVals, bodyIds, bodyVals);
            });
        });
        ShinobiLogger.module("progression", "Registered S2C packet: " + ID);
    }
}