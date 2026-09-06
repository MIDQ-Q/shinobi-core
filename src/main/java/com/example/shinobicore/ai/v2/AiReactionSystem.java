package com.example.shinobicore.ai.v2;

import net.minecraft.server.network.ServerPlayerEntity;

public class AiReactionSystem {
    public static boolean isPlayerCasting(ServerPlayerEntity player) {
        return com.example.shinobicore.combat.CastingServerState.isCasting(player);
    }
    
    public static boolean isPlayerBlocking(ServerPlayerEntity player) {
        // Placeholder for block detection
        return false; 
    }
}