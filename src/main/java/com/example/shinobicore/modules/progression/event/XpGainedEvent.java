package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record XpGainedEvent(ServerPlayerEntity player, int amount, String source) {}