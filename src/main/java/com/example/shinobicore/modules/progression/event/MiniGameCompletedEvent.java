package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record MiniGameCompletedEvent(ServerPlayerEntity player, String gameId, boolean success, int xpEarned) {}