package com.example.shinobicore.modules.clans.event;

import net.minecraft.server.network.ServerPlayerEntity;

public record ReputationChangedEvent(ServerPlayerEntity player, String factionId, int old, int current) {}