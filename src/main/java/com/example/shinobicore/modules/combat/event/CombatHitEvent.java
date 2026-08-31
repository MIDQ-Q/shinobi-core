package com.example.shinobicore.modules.combat.event;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
public record CombatHitEvent(ServerPlayerEntity attacker, LivingEntity target, float damage) {}