// SHINOBICORE:SPRINT15:FILE
package com.example.shinobicore.progression.v3;

import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * SPRINT 15 join handler.
 * Loads progression and sends it to the client.
 */
public final class ProgressionJoinHandler {
    private static boolean registered = false;

    private ProgressionJoinHandler() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            ServerPlayerEntity player = handler.getPlayer();

            ProgressionV3.ensureLoaded(player);
            ProgressionV3ServerSync.send(player, ProgressionV3.get(player.getUuid()));
        });
    }
}