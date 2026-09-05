package com.example.shinobicore.ai;

import net.fabricmc.fabric.api.object.builder.v1.entity.FabricDefaultAttributeRegistry;
import net.fabricmc.fabric.api.object.builder.v1.entity.FabricEntityTypeBuilder;
import net.minecraft.entity.EntityDimensions;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.SpawnGroup;
import net.minecraft.entity.attribute.DefaultAttributeContainer;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.mob.HostileEntity;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

public class AiEntities {

    /** Base HP for rogue ninja. Tune this single number to make them tougher/weaker. */
    public static final double BASE_HP = 40.0;
    /** Base melee knockback resistance */
    public static final double BASE_KB = 0.1;
    /** Movement speed (vanilla zombie = 0.23) */
    public static final double BASE_SPEED = 0.60;

    public static final EntityType<SummonCloneEntity> SUMMON_CLONE = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier("shinobicore", "summon_clone"),
            FabricEntityTypeBuilder.create(SpawnGroup.CREATURE, SummonCloneEntity::new)
                    .dimensions(EntityDimensions.changing(0.6f, 0.85f))
                    .build());

    public static final EntityType<RogueNinjaEntity> ROGUE_NINJA = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier("shinobicore", "rogue_ninja"),
            FabricEntityTypeBuilder.create(SpawnGroup.MONSTER, RogueNinjaEntity::new)
                    .dimensions(EntityDimensions.changing(0.6f, 1.8f))
                    .build());

    public static void register() {
        FabricDefaultAttributeRegistry.register(ROGUE_NINJA, createNinjaAttributes());
    }

    public static net.minecraft.entity.attribute.DefaultAttributeContainer.Builder createNinjaAttributes() {
        return HostileEntity.createHostileAttributes()
                .add(EntityAttributes.GENERIC_MAX_HEALTH, BASE_HP)
                .add(EntityAttributes.GENERIC_MOVEMENT_SPEED, BASE_SPEED)
                .add(EntityAttributes.GENERIC_KNOCKBACK_RESISTANCE, BASE_KB)
                .add(EntityAttributes.GENERIC_ATTACK_DAMAGE, 2.0)
                .add(EntityAttributes.GENERIC_FOLLOW_RANGE, 20.0);
    }
}