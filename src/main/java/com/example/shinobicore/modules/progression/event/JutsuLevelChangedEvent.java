package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record JutsuLevelChangedEvent(ServerPlayerEntity player, String jutsuId, int oldLevel, int newLevel) {}