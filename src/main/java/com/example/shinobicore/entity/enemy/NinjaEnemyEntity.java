package com.example.shinobicore.entity.enemy;

import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.ai.goal.ActiveTargetGoal;
import net.minecraft.entity.ai.goal.LookAroundGoal;
import net.minecraft.entity.ai.goal.LookAtEntityGoal;
import net.minecraft.entity.ai.goal.SwimGoal;
import net.minecraft.entity.ai.goal.WanderAroundFarGoal;
import net.minecraft.entity.attribute.DefaultAttributeContainer;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.entity.mob.PathAwareEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.world.World;

/**
 * S9-01: Base ninja enemy entity.
 * All enemies use this single class with rank-based presets.
 * Combat FSM is managed by EnemyCombatController.
 * Movement (patrol, approach) is handled by Minecraft Goal system.
 */
public class NinjaEnemyEntity extends PathAwareEntity {
    private static final TrackedData<String> RANK_ID =
        DataTracker.registerData(NinjaEnemyEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Integer> FSM_STATE =
        DataTracker.registerData(NinjaEnemyEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Float> BLOCK_STAMINA =
        DataTracker.registerData(NinjaEnemyEntity.class, TrackedDataHandlerRegistry.FLOAT);

    private float currentChakra;
    private float maxChakra;
    private float currentStamina;
    private float maxStamina;
    private EnemyCombatController combatController;

    public NinjaEnemyEntity(EntityType<? extends PathAwareEntity> entityType, World world) {
        super(entityType, world);
        this.combatController = new EnemyCombatController(this);
    }

    @Override
    protected void initDataTracker() {
        super.initDataTracker();
        this.dataTracker.startTracking(RANK_ID, NinjaRank.GENIN.getId());
        this.dataTracker.startTracking(FSM_STATE, 0);
        this.dataTracker.startTracking(BLOCK_STAMINA, 100.0f);
    }

    public static DefaultAttributeContainer.Builder createNinjaEnemyAttributes() {
        return MobEntity.createMobAttributes()
            .add(EntityAttributes.GENERIC_MAX_HEALTH, 20.0)
            .add(EntityAttributes.GENERIC_MOVEMENT_SPEED, 0.25)
            .add(EntityAttributes.GENERIC_ATTACK_DAMAGE, 4.0)
            .add(EntityAttributes.GENERIC_FOLLOW_RANGE, 32.0);
    }

    @Override
    protected void initGoals() {
        // Movement goals (handled by Minecraft Goal system)
        this.goalSelector.add(0, new SwimGoal(this));
        this.goalSelector.add(5, new WanderAroundFarGoal(this, 0.8));
        this.goalSelector.add(6, new LookAtEntityGoal(this, PlayerEntity.class, 8.0f));
        this.goalSelector.add(7, new LookAroundGoal(this));
        // Target selection
        this.targetSelector.add(1, new ActiveTargetGoal<>(this, PlayerEntity.class, true));
    }

    public void setRank(NinjaRank rank) {
        this.dataTracker.set(RANK_ID, rank.getId());
        this.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH).setBaseValue(rank.getMaxHealth());
        this.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED).setBaseValue(rank.getMoveSpeed());
        this.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_DAMAGE).setBaseValue(rank.getBaseDamage());
        this.setHealth(rank.getMaxHealth());
        this.maxChakra = rank.getMaxChakra();
        this.currentChakra = rank.getMaxChakra();
        this.maxStamina = rank.getMaxStamina();
        this.currentStamina = rank.getMaxStamina();
        this.dataTracker.set(BLOCK_STAMINA, rank.getMaxStamina());
        // Rebuild attack list for new rank
        this.combatController = new EnemyCombatController(this);
    }

    public NinjaRank getRank() {
        return NinjaRank.fromId(this.dataTracker.get(RANK_ID));
    }

    public float getBlockStamina() { return this.dataTracker.get(BLOCK_STAMINA); }
    public void setBlockStamina(float v) { this.dataTracker.set(BLOCK_STAMINA, v); }

    @Override
    public void tick() {
        super.tick();
        // Run combat FSM on server side
        if (!this.getWorld().isClient && this.combatController != null) {
            this.combatController.tick();
            // Sync FSM state to client for rendering
            this.dataTracker.set(FSM_STATE, this.combatController.getState().ordinal());
        }
    }

    @Override
    public boolean damage(DamageSource source, float amount) {
        // S9-04: Block / Kawarimi check
        if (!this.getWorld().isClient && this.combatController != null) {
            boolean handled = this.combatController.onDamageTaken(amount);
            if (handled) {
                // Reduce damage (block) or negate (kawarimi)
                if (this.combatController.getState() == EnemyState.KAWARIMI) {
                    return false; // Negate
                }
                amount *= 0.3f; // Block reduces to 30%
            }
        }
        return super.damage(source, amount);
    }

    @Override
    public void writeCustomDataToNbt(NbtCompound nbt) {
        super.writeCustomDataToNbt(nbt);
        nbt.putString("Rank", this.getRank().getId());
        nbt.putFloat("Chakra", this.currentChakra);
        nbt.putFloat("Stamina", this.currentStamina);
        nbt.putFloat("BlockStamina", this.getBlockStamina());
    }

    @Override
    public void readCustomDataFromNbt(NbtCompound nbt) {
        super.readCustomDataFromNbt(nbt);
        NinjaRank rank = NinjaRank.fromId(nbt.getString("Rank"));
        this.setRank(rank);
        this.currentChakra = nbt.getFloat("Chakra");
        this.currentStamina = nbt.getFloat("Stamina");
        this.dataTracker.set(BLOCK_STAMINA, nbt.getFloat("BlockStamina"));
    }

    /**
     * Get current FSM state (for client rendering).
     */
    public EnemyState getFsmState() {
        int ordinal = this.dataTracker.get(FSM_STATE);
        EnemyState[] states = EnemyState.values();
        return ordinal >= 0 && ordinal < states.length ? states[ordinal] : EnemyState.IDLE;
    }
}