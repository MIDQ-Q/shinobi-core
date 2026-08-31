package com.example.shinobicore.modules.combat.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record WeaponSheathedEvent(ServerPlayerEntity player, boolean sheathed, String itemId) {}