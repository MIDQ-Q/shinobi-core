package com.example.shinobicore.modules.combat.event;
import net.minecraft.entity.Entity;
import net.minecraft.server.network.ServerPlayerEntity;
public record CombatParriedEvent(ServerPlayerEntity parrier, Entity attacker, boolean reflected) {}