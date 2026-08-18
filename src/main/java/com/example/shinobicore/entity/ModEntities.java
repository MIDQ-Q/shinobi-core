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
                    .trackRangeChunks(32)
                    .trackedUpdateRate(4)
                    .build()
    );

    public static final EntityType<ShurikenEntity> SHURIKEN = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "shuriken"),
            FabricEntityTypeBuilder.<ShurikenEntity>create(SpawnGroup.MISC, ShurikenEntity::new)
                    .dimensions(EntityDimensions.fixed(0.25f, 0.25f))
                    .trackRangeChunks(16)
                    .trackedUpdateRate(1)
                    .build()
    );

    
    public static final EntityType<RasenshurikenEntity> RASENSHURIKEN = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "rasenshuriken"),
        FabricEntityTypeBuilder.<RasenshurikenEntity>create(SpawnGroup.MISC, RasenshurikenEntity::new)
            .dimensions(EntityDimensions.fixed(1.5f, 1.5f))
            .trackRangeChunks(64)
            .trackedUpdateRate(2)
            .build()
    );

    public static final EntityType<RasenganHandEntity> RASENGAN_HAND = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "rasengan_hand"),
        FabricEntityTypeBuilder.<RasenganHandEntity>create(SpawnGroup.MISC, RasenganHandEntity::new)
            .dimensions(EntityDimensions.fixed(0.5f, 0.5f))
            .trackRangeChunks(32)
            .trackedUpdateRate(1)
            .build()
    );

    public static final EntityType<com.example.shinobicore.entity.VoxelProjectileEntity> VOXEL_PROJECTILE = Registry.register(
        Registries.ENTITY_TYPE, new Identifier(ShinobiCore.MOD_ID, "voxel_projectile"),
        FabricEntityTypeBuilder.<com.example.shinobicore.entity.VoxelProjectileEntity>create(SpawnGroup.MISC, com.example.shinobicore.entity.VoxelProjectileEntity::new)
            .dimensions(EntityDimensions.fixed(0.5f, 0.5f)).trackRangeChunks(64).trackedUpdateRate(2).build());

    
    public static final EntityType<com.example.shinobicore.entity.DotZoneEntity> DOT_ZONE = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "dot_zone"),
            FabricEntityTypeBuilder.<com.example.shinobicore.entity.DotZoneEntity>create(SpawnGroup.MISC, com.example.shinobicore.entity.DotZoneEntity::new)
                .dimensions(EntityDimensions.fixed(1.0f, 1.0f))
                .trackRangeChunks(64)
                .trackedUpdateRate(4)
                .build()
    );

    public static final EntityType<DragonEntity> DRAGON = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "dragon"),
        FabricEntityTypeBuilder.<DragonEntity>create(SpawnGroup.MISC, DragonEntity::new)
            .dimensions(EntityDimensions.fixed(1.0f, 1.0f))
            .trackRangeChunks(64)
            .trackedUpdateRate(2)
            .build()
    );

    public static final EntityType<com.example.shinobicore.entity.SamuraiTeacherEntity> SAMURAI_TEACHER = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "samurai_teacher"),
        FabricEntityTypeBuilder.<com.example.shinobicore.entity.SamuraiTeacherEntity>create(SpawnGroup.CREATURE, com.example.shinobicore.entity.SamuraiTeacherEntity::new)
            .dimensions(EntityDimensions.fixed(0.6f, 1.8f))
            .trackRangeChunks(10)
            .build());

    public static final EntityType<com.example.shinobicore.entity.enemy.NinjaEnemyEntity> NINJA_ENEMY = Registry.register(
        Registries.ENTITY_TYPE,
        new Identifier(ShinobiCore.MOD_ID, "ninja_enemy"),
        FabricEntityTypeBuilder.<com.example.shinobicore.entity.enemy.NinjaEnemyEntity>create(SpawnGroup.MONSTER, com.example.shinobicore.entity.enemy.NinjaEnemyEntity::new)
            .dimensions(EntityDimensions.fixed(0.6f, 1.8f))
            .trackRangeChunks(64)
            .trackedUpdateRate(3)
            .build());

    public static void register() {
        ShinobiCore.LOGGER.info("Registered entities");
    }
}