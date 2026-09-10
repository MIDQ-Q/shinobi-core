package com.example.shinobicore.ai.v2;

import net.minecraft.server.network.ServerPlayerEntity;

public class AiReactionSystem {
    public static boolean isPlayerCasting(ServerPlayerEntity player) {
        // Migrated from dead CastingServerState to active ActivationSystem
        return com.example.shinobicore.jutsu.executor.ActivationSystem.hasActive(player.getUuid());
    }

    public static boolean isPlayerBlocking(ServerPlayerEntity player) {
        // Placeholder for block detection
        return false;
    }
}