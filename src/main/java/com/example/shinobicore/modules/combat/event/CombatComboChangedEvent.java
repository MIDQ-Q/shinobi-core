package com.example.shinobicore.modules.combat.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record CombatComboChangedEvent(ServerPlayerEntity player, int oldStep, int newStep, String weaponClass) {}