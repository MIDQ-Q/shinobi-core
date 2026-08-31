package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record StatLevelChangedEvent(ServerPlayerEntity player, String statId, int oldLevel, int newLevel) {}