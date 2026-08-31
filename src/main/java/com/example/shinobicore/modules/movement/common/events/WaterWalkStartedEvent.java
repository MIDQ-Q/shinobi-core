package com.example.shinobicore.modules.movement.common.events;

import net.minecraft.entity.player.PlayerEntity;

public record WaterWalkStartedEvent(PlayerEntity player) {}