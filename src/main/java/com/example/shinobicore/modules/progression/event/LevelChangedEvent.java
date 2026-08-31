package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record LevelChangedEvent(ServerPlayerEntity player, int oldLevel, int newLevel) {}