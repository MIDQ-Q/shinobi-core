package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record SpGainedEvent(ServerPlayerEntity player, int amount) {}