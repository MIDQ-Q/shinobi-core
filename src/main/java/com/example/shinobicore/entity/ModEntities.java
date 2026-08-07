package com.example.shinobicore.entity;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.object.builder.v1.entity.FabricEntityTypeBuilder;
import net.minecraft.entity.EntityDimensions;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.SpawnGroup;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

public class ModEntities {
    public static final EntityType<NinjaProjectileEntity> NINJA_PROJECTILE = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "ninja_projectile"),
        FabricEntityTypeBuilder.<NinjaProjectileEntity>create(SpawnGroup.MISC, NinjaProjectileEntity::new)
            .dimensions(EntityDimensions.fixed(0.5f, 0.5f))
            .trackRangeChunks(4)
            .trackedUpdateRate(10)
            .build()
    );

    public static void register() {
        ShinobiCore.LOGGER.info("Registered entities");
    }
}