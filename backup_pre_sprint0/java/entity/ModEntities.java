package com.example.shinobicore.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.enemy.NinjaEnemyEntity;
import com.example.shinobicore.entity.CloneEntity;
import net.fabricmc.fabric.api.object.builder.v1.entity.FabricDefaultAttributeRegistry;
import net.fabricmc.fabric.api.object.builder.v1.entity.FabricEntityTypeBuilder;
import net.minecraft.entity.EntityDimensions;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.SpawnGroup;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

/**
 * Entity registration (HLD Section 8)
 */
public final class ModEntities {

    public static final EntityType<NinjaProjectileEntity> NINJA_PROJECTILE = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "ninja_projectile"),
        FabricEntityTypeBuilder.<NinjaProjectileEntity>create(SpawnGroup.MISC, NinjaProjectileEntity::new)
            .dimensions(EntityDimensions.fixed(0.5f, 0.5f))
            .trackRangeChunks(64)
            .build()
    );

    public static final EntityType<NinjaEnemyEntity> NINJA_ENEMY = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "ninja_enemy"),
        FabricEntityTypeBuilder.<NinjaEnemyEntity>create(SpawnGroup.MONSTER, NinjaEnemyEntity::new)
            .dimensions(EntityDimensions.fixed(0.6f, 1.9f))
            .trackRangeChunks(8)
            .build()
    );

    public static final EntityType<CloneEntity> CLONE = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "clone"),
        FabricEntityTypeBuilder.<CloneEntity>create(SpawnGroup.MISC, CloneEntity::new)
            .dimensions(EntityDimensions.fixed(0.6f, 1.8f))
            .trackRangeChunks(8)
            .build()
    );

    private ModEntities() {}

    public static void init() {
        FabricDefaultAttributeRegistry.register(NINJA_ENEMY, NinjaEnemyEntity.createNinjaEnemyAttributes());
        FabricDefaultAttributeRegistry.register(CLONE, CloneEntity.createCloneAttributes());
        ShinobiCore.LOGGER.info("ModEntities registered");
    }
}