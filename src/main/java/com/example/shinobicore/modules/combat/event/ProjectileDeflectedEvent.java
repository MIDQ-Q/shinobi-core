package com.example.shinobicore.modules.combat.event;
import net.minecraft.entity.Entity;
import net.minecraft.server.network.ServerPlayerEntity;
public record ProjectileDeflectedEvent(ServerPlayerEntity defender, Entity projectile) {}