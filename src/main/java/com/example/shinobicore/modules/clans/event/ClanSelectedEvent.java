package com.example.shinobicore.modules.clans.event;

import net.minecraft.server.network.ServerPlayerEntity;

public record ClanSelectedEvent(ServerPlayerEntity player, String clanId) {}