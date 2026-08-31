package com.example.shinobicore.modules.combat.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record CombatStanceChangedEvent(ServerPlayerEntity player, String oldStance, String newStance) {}