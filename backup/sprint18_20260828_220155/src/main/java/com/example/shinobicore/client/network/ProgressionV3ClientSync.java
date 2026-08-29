// SHINOBICORE:SPRINT15:FILE
package com.example.shinobicore.client.network;

import com.example.shinobicore.progression.v3.ProgressionClientState;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketSender;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayNetworkHandler;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/**
 * SPRINT 15 client receiver for progression sync.
 */
public final class ProgressionV3ClientSync {
    private static boolean registered = false;

    private ProgressionV3ClientSync() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        ClientPlayNetworking.registerGlobalReceiver(
                new Identifier("shinobicore", "progression_v3_sync"),
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
    }
}