package com.example.shinobicore.modules.progression.event;

import net.minecraft.server.network.ServerPlayerEntity;

public record ReputationChangedEvent(
    ServerPlayerEntity player,
    String factionId,
    int oldValue,
    int newValue
) {}