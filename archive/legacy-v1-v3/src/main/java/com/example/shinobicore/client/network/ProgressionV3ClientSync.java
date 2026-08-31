// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.client.network;

import com.example.shinobicore.progression.v3.ProgressionClientState;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayNetworkHandler;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/**
 * SPRINT 18 client receiver for progression sync.
 */
public final class ProgressionV3ClientSync {
    private static boolean registered = false;

    private static final Identifier OLD_ID =
            new Identifier("shinobicore", "progression_v3_sync");

    private static final Identifier FULL_ID =
            new Identifier("shinobicore", "progression_v3_full_sync");

    private ProgressionV3ClientSync() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        ClientPlayNetworking.registerGlobalReceiver(
                OLD_ID,
                (MinecraftClient client,
                 ClientPlayNetworkHandler handler,
                 PacketByteBuf buf,
                 PacketSender responseSender) -> {

                    int level = buf.readInt();
                    int xp = buf.readInt();
                    int sp = buf.readInt();

                    client.execute(() -> {
                        ProgressionClientState.setLevel(level);
                        ProgressionClientState.setXp(xp);
                        ProgressionClientState.setSp(sp);
                    });
                }
        );

        ClientPlayNetworking.registerGlobalReceiver(
                FULL_ID,
                (MinecraftClient client,
                 ClientPlayNetworkHandler handler,
                 PacketByteBuf buf,
                 PacketSender responseSender) -> {

                    int level = buf.readInt();
                    int xp = buf.readInt();
                    int sp = buf.readInt();

                    int count = buf.readVarInt();

                    java.util.LinkedHashMap<String, int[]> stats = new java.util.LinkedHashMap<>();

                    for (int i = 0; i < count; i++) {
                        String stat = buf.readString();
                        int statLevel = buf.readVarInt();
                        int statXp = buf.readVarInt();

                        stats.put(stat, new int[]{statLevel, statXp});
                    }

                    client.execute(() -> {
                        ProgressionClientState.setLevel(level);
                        ProgressionClientState.setXp(xp);
                        ProgressionClientState.setSp(sp);

                        ProgressionClientState.clearStats();

                        for (java.util.Map.Entry<String, int[]> entry : stats.entrySet()) {
                            ProgressionClientState.setStat(
                                    entry.getKey(),
                                    entry.getValue()[0],
                                    entry.getValue()[1]
                            );
                        }
                    });
                }
        );
    }
}