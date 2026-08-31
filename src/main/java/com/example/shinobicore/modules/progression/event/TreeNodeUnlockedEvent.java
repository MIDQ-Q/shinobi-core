package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
public record TreeNodeUnlockedEvent(ServerPlayerEntity player, String nodeId) {}