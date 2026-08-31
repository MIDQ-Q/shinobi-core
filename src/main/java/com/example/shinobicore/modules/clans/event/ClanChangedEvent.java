package com.example.shinobicore.modules.clans.event;

import net.minecraft.server.network.ServerPlayerEntity;

public record ClanChangedEvent(ServerPlayerEntity player, String oldClanId, String newClanId) {}