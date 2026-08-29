package com.example.shinobicore.entity;

import net.minecraft.entity.EntityType;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.mob.PathAwareEntity;
import net.minecraft.entity.attribute.DefaultAttributeContainer;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.world.World;
import software.bernie.geckolib.animatable.GeoEntity;
import software.bernie.geckolib.core.animatable.instance.AnimatableInstanceCache;
import software.bernie.geckolib.core.animatable.instance.SingletonAnimatableInstanceCache;
import software.bernie.geckolib.core.animation.AnimatableManager;
import software.bernie.geckolib.core.animation.AnimationController;
import software.bernie.geckolib.core.animation.AnimationState;
import software.bernie.geckolib.core.animation.RawAnimation;
import software.bernie.geckolib.core.object.PlayState;

import java.util.UUID;

/**
 * Static shadow clone decoy. Stands still; on damage disperses
 * (poof particles) and grants XP to its owner.
 * HLD: Blueprint (static decoy clones)
 * Yarn 1.20.1: readCustomDataFromNbt / writeCustomDataToNbt are PUBLIC.
 */
public class CloneEntity extends PathAwareEntity implements GeoEntity {

    private final AnimatableInstanceCache animCache = new SingletonAnimatableInstanceCache(this);
    private UUID ownerId;

    public CloneEntity(EntityType<? extends PathAwareEntity> type, World world) {
        super(type, world);
    }

    public static DefaultAttributeContainer.Builder createCloneAttributes() {
        return PathAwareEntity.createMobAttributes()
            .add(EntityAttributes.GENERIC_MAX_HEALTH, 10.0)
            .add(EntityAttributes.GENERIC_MOVEMENT_SPEED, 0.0);
    }

    public void setOwner(UUID owner) { this.ownerId = owner; }

    @Override
    protected void initGoals() {
        // No goals: clone stands still (decoy).
    }

    @Override
    public boolean damage(DamageSource source, float amount) {
        boolean result = super.damage(source, amount);
        if (result && !this.getWorld().isClient()) {
            disperse();
        }
        return result;
    }

    private void disperse() {
        if (this.getWorld() instanceof ServerWorld sw) {
            for (int i = 0; i < 20; i++) {
                sw.addParticle(ParticleTypes.POOF,
                    this.getX(), this.getY() + 1.0, this.getZ(),
                    (this.random.nextFloat() - 0.5f) * 0.5,
                    this.random.nextFloat() * 0.4,
                    (this.random.nextFloat() - 0.5f) * 0.5);
            }
            if (ownerId != null) {
                ServerPlayerEntity owner = sw.getServer().getPlayerManager().getPlayer(ownerId);
                if (owner != null) {
                    owner.addExperience(15);
                }
            }
        }
        this.discard();
    }

    @Override
    public void readCustomDataFromNbt(NbtCompound nbt) {
        if (nbt.containsUuid("OwnerId")) this.ownerId = nbt.getUuid("OwnerId");
    }

    @Override
    public void writeCustomDataToNbt(NbtCompound nbt) {
        if (this.ownerId != null) nbt.putUuid("OwnerId", this.ownerId);
    }

    @Override
    public void registerControllers(AnimatableManager.ControllerRegistrar controllers) {
        controllers.add(new AnimationController<>(this, "idle", 5, this::idlePredicate));
    }

    private PlayState idlePredicate(AnimationState<CloneEntity> event) {
        event.getController().setAnimation(RawAnimation.begin().thenLoop("animation.ninja_enemy.idle"));
        return PlayState.CONTINUE;
    }

    @Override
    public AnimatableInstanceCache getAnimatableInstanceCache() { return this.animCache; }
}