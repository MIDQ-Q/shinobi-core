package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record ElementAttunedEvent(ServerPlayerEntity player, String elementId) {}