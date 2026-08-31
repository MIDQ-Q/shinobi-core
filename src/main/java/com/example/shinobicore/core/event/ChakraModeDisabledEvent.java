package com.example.shinobicore.core.event;

import net.minecraft.server.network.ServerPlayerEntity;

public record ChakraModeDisabledEvent(ServerPlayerEntity player) {}