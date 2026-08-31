package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record SpSpentEvent(ServerPlayerEntity player, int amount, String reason) {}