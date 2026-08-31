package com.example.shinobicore.entity;

import com.example.shinobicore.util.ShinobiLogger;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.ai.goal.*;
import net.minecraft.entity.attribute.DefaultAttributeContainer;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.mob.HostileEntity;
import net.minecraft.world.World;
import software.bernie.geckolib.animatable.GeoEntity;
import software.bernie.geckolib.core.animatable.instance.AnimatableInstanceCache;
import software.bernie.geckolib.core.animatable.instance.SingletonAnimatableInstanceCache;
import software.bernie.geckolib.core.animation.AnimatableManager;

public abstract class ShinobiGeoEntity extends HostileEntity implements GeoEntity {
    private final AnimatableInstanceCache animCache = new SingletonAnimatableInstanceCache(this);
    protected String rank = "genin";

    protected ShinobiGeoEntity(EntityType<? extends HostileEntity> type, World world) {
        super(type, world);
    }

    @Override
    public void registerControllers(AnimatableManager.ControllerRegistrar controllers) {}

    @Override
    public AnimatableInstanceCache getAnimatableInstanceCache() { return this.animCache; }

    public static DefaultAttributeContainer.Builder createShinobiAttributes() {
        return HostileEntity.createHostileAttributes()
            .add(EntityAttributes.GENERIC_MAX_HEALTH, 40.0)
            .add(EntityAttributes.GENERIC_MOVEMENT_SPEED, 0.32)
            .add(EntityAttributes.GENERIC_ATTACK_DAMAGE, 6.0)
            .add(EntityAttributes.GENERIC_FOLLOW_RANGE, 40.0)
            .add(EntityAttributes.GENERIC_ARMOR, 2.0)
            .add(EntityAttributes.GENERIC_KNOCKBACK_RESISTANCE, 0.3);
    }

    @Override
    protected void initGoals() {
        this.goalSelector.add(0, new SwimGoal(this));
        this.goalSelector.add(1, new MeleeAttackGoal(this, 1.2, false));
        this.goalSelector.add(5, new WanderAroundFarGoal(this, 0.8));
        this.goalSelector.add(6, new LookAtEntityGoal(this, net.minecraft.entity.player.PlayerEntity.class, 8.0f));
        this.goalSelector.add(6, new LookAroundGoal(this));
        this.targetSelector.add(1, new ActiveTargetGoal<>(this, net.minecraft.entity.player.PlayerEntity.class, true));
    }

    public String getRank() { return rank; }

    @Override
    public boolean damage(net.minecraft.entity.damage.DamageSource source, float amount) {
        ShinobiLogger.debug("Entity %s took %.1f damage from %s", this.getName().getString(), amount, source.getName());
        return super.damage(source, amount);
    }
}