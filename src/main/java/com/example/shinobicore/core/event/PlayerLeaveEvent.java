package com.example.shinobicore.core.event;

import net.minecraft.server.network.ServerPlayerEntity;

public record PlayerLeaveEvent(ServerPlayerEntity player) {}