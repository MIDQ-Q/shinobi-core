package com.example.shinobicore.modules.combat.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record WeaponDrawnEvent(ServerPlayerEntity player, String itemId) {}