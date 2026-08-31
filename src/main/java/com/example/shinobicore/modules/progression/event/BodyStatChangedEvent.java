package com.example.shinobicore.modules.progression.event;

import net.minecraft.server.network.ServerPlayerEntity;

public record BodyStatChangedEvent(
    ServerPlayerEntity player,
    String bodyStatId,
    int oldLevel,
    int newLevel
) {}