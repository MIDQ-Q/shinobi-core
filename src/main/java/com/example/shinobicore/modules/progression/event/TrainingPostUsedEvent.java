package com.example.shinobicore.modules.progression.event;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.BlockPos;
public record TrainingPostUsedEvent(ServerPlayerEntity player, BlockPos pos) {}