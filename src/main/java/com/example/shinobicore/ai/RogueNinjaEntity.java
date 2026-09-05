package com.example.shinobicore.ai;

import net.minecraft.entity.EntityType;
import net.minecraft.entity.mob.PathAwareEntity;
import net.minecraft.world.World;

public class RogueNinjaEntity extends PathAwareEntity {
    public RogueNinjaEntity(EntityType<? extends PathAwareEntity> type, World world) {
        super(type, world);
    }
}