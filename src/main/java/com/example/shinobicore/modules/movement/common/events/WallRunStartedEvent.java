package com.example.shinobicore.modules.movement.common.events;

import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.math.Vec3d;

public record WallRunStartedEvent(PlayerEntity player, Vec3d normal) {}