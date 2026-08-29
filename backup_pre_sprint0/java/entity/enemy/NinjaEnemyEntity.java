package com.example.shinobicore.entity.enemy;

import com.example.shinobicore.world.ShinobiWorldState;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.ai.goal.LookAroundGoal;
import net.minecraft.entity.ai.goal.SwimGoal;
import net.minecraft.entity.ai.goal.WanderAroundFarGoal;
import net.minecraft.entity.attribute.DefaultAttributeContainer;
import net.minecraft.entity.attribute.EntityAttributeInstance;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.mob.PathAwareEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.Identifier;
import net.minecraft.world.World;

// GeckoLib 4.4.9 (Fabric 1.20.1) - correct core.* packages
import software.bernie.geckolib.animatable.GeoEntity;
import software.bernie.geckolib.core.animatable.instance.AnimatableInstanceCache;
import software.bernie.geckolib.core.animatable.instance.SingletonAnimatableInstanceCache;
import software.bernie.geckolib.core.animation.AnimatableManager;
import software.bernie.geckolib.core.animation.AnimationController;
import software.bernie.geckolib.core.animation.AnimationState;
import software.bernie.geckolib.core.animation.RawAnimation;
import software.bernie.geckolib.core.object.PlayState;

/**
 * Rogue ninja enemy with GeckoLib 4.4.9 animations and FSM combat AI.
 * HLD: Section 5 (Enemy AI, GeckoLib integration, PersistentState on death)
 * Yarn 1.20.1: readCustomDataFromNbt / writeCustomDataToNbt
 */
public class NinjaEnemyEntity extends PathAwareEntity implements GeoEntity {

    private final AnimatableInstanceCache animCache =
        new SingletonAnimatableInstanceCache(this);
    private final EnemyCombatController controller =
        new EnemyCombatController(this);
    private String rankId = "genin";

    public NinjaEnemyEntity(EntityType<? extends PathAwareEntity> type, World world) {
        super(type, world);
    }

    public static DefaultAttributeContainer.Builder createNinjaEnemyAttributes() {
        return PathAwareEntity.createMobAttributes()
            .add(EntityAttributes.GENERIC_MAX_HEALTH, 40.0)
            .add(EntityAttributes.GENERIC_MOVEMENT_SPEED, 0.28)
            .add(EntityAttributes.GENERIC_FOLLOW_RANGE, 24.0);
    }

    @Override
    protected void initGoals() {
        this.goalSelector.add(0, new SwimGoal(this));
        this.goalSelector.add(7, new WanderAroundFarGoal(this, 1.0));
        this.goalSelector.add(8, new LookAroundGoal(this));
    }

    public NinjaRank getRank() { return NinjaRank.fromId(this.rankId); }

    public void setRankId(String id) {
        this.rankId = NinjaRank.fromId(id).getId();
        EntityAttributeInstance hp = this.getAttributeInstance(
            EntityAttributes.GENERIC_MAX_HEALTH);
        if (hp != null) {
            hp.setBaseValue(this.getRank().getMaxHp());
            this.setHealth(this.getRank().getMaxHp());
        }
    }

    public EnemyCombatController getController() { return this.controller; }

    @Override
    public void tick() {
        super.tick();
        if (!this.getWorld().isClient() && this.getWorld() instanceof ServerWorld sw) {
            this.controller.tick(sw);
        }
    }

    @Override
    public boolean damage(DamageSource source, float amount) {
        float finalAmount = amount;
        if (this.controller.isBlocking()) {
            finalAmount = amount * 0.3f;
        }
        boolean result = super.damage(source, finalAmount);
        if (result && this.random.nextFloat() < 0.25f) {
            this.controller.requestKawarimi();
        }
        return result;
    }

    @Override
    public void onDeath(DamageSource damageSource) {
        super.onDeath(damageSource);
        if (!this.getWorld().isClient() && this.getWorld().getServer() != null) {
            ShinobiWorldState state = ShinobiWorldState.get(this.getWorld().getServer());
            state.addKill(this.rankId);
        }
    }

    @Override
    public void readCustomDataFromNbt(NbtCompound nbt) {
        if (nbt.contains("RankId")) {
            this.rankId = nbt.getString("RankId");
        }
    }

    @Override
    public void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putString("RankId", this.rankId);
    }

    // ---------- GeckoLib 4.4.9 (core.* packages) ----------

    @Override
    public void registerControllers(AnimatableManager.ControllerRegistrar controllers) {
        controllers.add(new AnimationController<>(this, "move", 5, this::movePredicate));
        controllers.add(new AnimationController<>(this, "action", 3, this::actionPredicate));
    }

    private PlayState movePredicate(AnimationState<NinjaEnemyEntity> event) {
        EnemyState s = this.controller.getState();
        if (s == EnemyState.ATTACK || s == EnemyState.TELEGRAPH) {
            return PlayState.STOP;
        }
        if (event.isMoving()) {
            event.getController().setAnimation(
                RawAnimation.begin().thenLoop("animation.ninja_enemy.walk"));
        } else {
            event.getController().setAnimation(
                RawAnimation.begin().thenLoop("animation.ninja_enemy.idle"));
        }
        return PlayState.CONTINUE;
    }

    private PlayState actionPredicate(AnimationState<NinjaEnemyEntity> event) {
        EnemyState s = this.controller.getState();
        if (s == EnemyState.TELEGRAPH) {
            event.getController().setAnimation(
                RawAnimation.begin().thenPlay("animation.ninja_enemy.telegraph"));
            return PlayState.CONTINUE;
        }
        if (s == EnemyState.ATTACK) {
            event.getController().setAnimation(
                RawAnimation.begin().thenPlay("animation.ninja_enemy.attack"));
            return PlayState.CONTINUE;
        }
        return PlayState.STOP;
    }

    @Override
    public AnimatableInstanceCache getAnimatableInstanceCache() {
        return this.animCache;
    }
}