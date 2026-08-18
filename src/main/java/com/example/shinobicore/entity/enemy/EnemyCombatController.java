package com.example.shinobicore.entity.enemy;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.ai.goal.ActiveTargetGoal;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * S9-02: Combat FSM controller for NinjaEnemyEntity.
 * Manages state transitions, telegraphs, attacks, block, dash, kawarimi.
 * Movement goals (patrol, approach) are handled by Minecraft Goal system.
 * Combat decisions are handled here inside tick().
 */
public class EnemyCombatController {
    private final NinjaEnemyEntity entity;
    private EnemyState currentState = EnemyState.IDLE;
    private EnemyState previousState = EnemyState.IDLE;
    private int stateTimer = 0;
    private int telegraphRemaining = 0;
    private EnemyAttack pendingAttack = null;
    private final Map<String, Integer> attackCooldowns = new HashMap<>();
    private final List<EnemyAttack> attacks = new ArrayList<>();
    private final List<EnemyAttack> availableAttacks = new ArrayList<>();
    private int recoverTicks = 0;
    private int dashCooldown = 0;
    private int kawarimiCooldown = 0;
    private int blockHitCount = 0;
    private static final int BLOCK_MAX_HITS = 5;
    private static final int RECOVER_DURATION = 20;
    private static final int DASH_COOLDOWN = 60;
    private static final int KAWARIMI_COOLDOWN = 200;
    private int phase = 1; // Mini-boss phase

    public EnemyCombatController(NinjaEnemyEntity entity) {
        this.entity = entity;
        buildAttackList();
    }

    private void buildAttackList() {
        NinjaRank rank = entity.getRank();
        float dmg = rank.getBaseDamage();
        int tele = rank.getTelegraphTicks();
        int count = rank.getAttackCount();

        attacks.add(EnemyAttack.melee(dmg, tele, 30));
        if (count >= 2) attacks.add(EnemyAttack.ranged(dmg * 0.8f, 16f, tele, 40));
        if (count >= 3) attacks.add(EnemyAttack.aoe(dmg * 1.2f, 5f, tele + 5, 60));
        if (count >= 4) attacks.add(EnemyAttack.dashAttack(dmg * 0.6f, tele, DASH_COOLDOWN));
    }

    public EnemyState getState() { return currentState; }
    public int getPhase() { return phase; }

    /**
     * Called every server tick from NinjaEnemyEntity.tick().
     */
    public void tick() {
        stateTimer++;
        if (dashCooldown > 0) dashCooldown--;
        if (kawarimiCooldown > 0) kawarimiCooldown--;
        updateCooldowns();

        // Mini-boss phase check
        if (entity.getRank().isBossRank()) {
            updateBossPhase();
        }

        switch (currentState) {
            case IDLE -> tickIdle();
            case PATROL -> tickPatrol();
            case APPROACH -> tickApproach();
            case TELEGRAPH -> tickTelegraph();
            case MELEE_ATTACK, RANGED_ATTACK, AOE_ATTACK -> tickExecuteAttack();
            case BLOCK -> tickBlock();
            case DASH -> tickDash();
            case KAWARIMI -> tickKawarimi();
            case RECOVER -> tickRecover();
            case FLEE -> tickFlee();
            default -> setState(EnemyState.IDLE);
        }
    }

    private void updateCooldowns() {
        attackCooldowns.replaceAll((k, v) -> v > 0 ? v - 1 : 0);
    }

    private void updateBossPhase() {
        float hpPercent = entity.getHealth() / entity.getMaxHealth();
        if (hpPercent > 0.7f) {
            if (phase != 1) { phase = 1; onPhaseChange(1); }
        } else if (hpPercent > 0.3f) {
            if (phase != 2) { phase = 2; onPhaseChange(2); }
        } else {
            if (phase != 3) { phase = 3; onPhaseChange(3); }
        }
    }

    private void onPhaseChange(int newPhase) {
        if (!(entity.getWorld() instanceof ServerWorld sw)) return;
        // Phase change: sound + particles
        sw.playSound(null, entity.getBlockPos(),
            net.minecraft.sound.SoundEvents.ENTITY_ENDER_DRAGON_GROWL,
            SoundCategory.HOSTILE, 1.5f, 0.8f + newPhase * 0.2f);
        sw.spawnParticles(ParticleTypes.SOUL_FIRE_FLAME,
            entity.getX(), entity.getY() + 1, entity.getZ(),
            20, 0.5, 0.5, 0.5, 0.05);
        ShinobiCore.LOGGER.info("[ENEMY] Boss phase changed to {}", newPhase);
    }

    private float getPhaseSpeedMultiplier() {
        if (!entity.getRank().isBossRank()) return 1.0f;
        switch (phase) {
            case 2: return 1.2f;
            case 3: return 1.4f;
            default: return 1.0f;
        }
    }

    private float getPhaseTelegraphMultiplier() {
        if (!entity.getRank().isBossRank()) return 1.0f;
        switch (phase) {
            case 2: return 0.7f;
            case 3: return 0.5f;
            default: return 1.0f;
        }
    }

    // === STATE TICKS ===

    private void tickIdle() {
        LivingEntity target = entity.getTarget();
        if (target != null && target.isAlive()) {
            float dist = entity.distanceTo(target);
            float aggroRange = 16.0f * entity.getRank().getAggression();
            if (dist <= aggroRange) {
                setState(EnemyState.APPROACH);
            }
        }
        // Low HP flee
        if (entity.getHealth() < entity.getMaxHealth() * 0.15f) {
            setState(EnemyState.FLEE);
        }
    }

    private void tickPatrol() {
        // Patrol is handled by WanderAroundGoal in Minecraft Goal system.
        // Here we just check for targets.
        LivingEntity target = entity.getTarget();
        if (target != null && target.isAlive()) {
            float dist = entity.distanceTo(target);
            if (dist <= 16.0f * entity.getRank().getAggression()) {
                setState(EnemyState.APPROACH);
            }
        }
    }

    private void tickApproach() {
        LivingEntity target = entity.getTarget();
        if (target == null || !target.isAlive()) {
            setState(EnemyState.IDLE);
            return;
        }

        float dist = entity.distanceTo(target);

        // Decide attack
        EnemyAttack chosen = chooseAttack(dist);
        if (chosen != null) {
            pendingAttack = chosen;
            telegraphRemaining = (int)(chosen.getTelegraphTicks() * getPhaseTelegraphMultiplier());
            setState(EnemyState.TELEGRAPH);
            return;
        }

        // Dash to close distance
        if (dist > 8f && dashCooldown <= 0 && entity.getWorld().getRandom().nextFloat() < 0.3f) {
            setState(EnemyState.DASH);
            return;
        }

        // Flee if low HP
        if (entity.getHealth() < entity.getMaxHealth() * 0.15f) {
            setState(EnemyState.FLEE);
        }
    }

    private EnemyAttack chooseAttack(float dist) {
        availableAttacks.clear();
        for (EnemyAttack atk : attacks) {
            String cdKey = atk.getName();
            int cd = attackCooldowns.getOrDefault(cdKey, 0);
            if (cd > 0) continue;

            switch (atk.getType()) {
                case MELEE -> { if (dist <= atk.getRange()) availableAttacks.add(atk); }
                case RANGED -> { if (dist > 3f && dist <= atk.getRange()) availableAttacks.add(atk); }
                case AOE -> { if (dist <= atk.getRange()) availableAttacks.add(atk); }
                case DASH_ATTACK -> { if (dist > 2f && dist <= atk.getRange() && dashCooldown <= 0) availableAttacks.add(atk); }
            }
        }
        if (availableAttacks.isEmpty()) return null;
        return availableAttacks.get(entity.getWorld().getRandom().nextInt(availableAttacks.size()));
    }

    private void tickTelegraph() {
        telegraphRemaining--;

        // Play telegraph sound at start
        if (telegraphRemaining == (int)(pendingAttack.getTelegraphTicks() * getPhaseTelegraphMultiplier()) - 1) {
            playTelegraphSound();
            spawnTelegraphParticles();
        }

        if (telegraphRemaining <= 0) {
            // Execute attack
            switch (pendingAttack.getType()) {
                case MELEE -> setState(EnemyState.MELEE_ATTACK);
                case RANGED -> setState(EnemyState.RANGED_ATTACK);
                case AOE -> setState(EnemyState.AOE_ATTACK);
                case DASH_ATTACK -> setState(EnemyState.DASH);
            }
        }
    }

    private void playTelegraphSound() {
        if (!(entity.getWorld() instanceof ServerWorld sw)) return;
        sw.playSound(null, entity.getBlockPos(), pendingAttack.getTelegraphSound(),
            SoundCategory.HOSTILE, 1.0f, 1.0f);
    }

    private void spawnTelegraphParticles() {
        if (!(entity.getWorld() instanceof ServerWorld sw)) return;
        sw.spawnParticles(ParticleTypes.ANGRY_VILLAGER,
            entity.getX(), entity.getY() + entity.getHeight() + 0.3, entity.getZ(),
            5, 0.2, 0.2, 0.2, 0.02);
    }

    private void tickExecuteAttack() {
        if (pendingAttack == null) { setState(EnemyState.RECOVER); return; }

        LivingEntity target = entity.getTarget();
        if (target != null && target.isAlive()) {
            float dist = entity.distanceTo(target);
            float dmg = pendingAttack.getDamage() * getPhaseSpeedMultiplier();

            switch (currentState) {
                case MELEE_ATTACK -> {
                    if (dist <= pendingAttack.getRange() + 0.5f) {
                        target.damage(entity.getDamageSources().mobAttack(entity), dmg);
                    }
                }
                case RANGED_ATTACK -> {
                    spawnProjectile(target, dmg);
                }
                case AOE_ATTACK -> {
                    dealAoeDamage(dmg, pendingAttack.getRange());
                }
                default -> {}
            }
        }

        attackCooldowns.put(pendingAttack.getName(), pendingAttack.getCooldownTicks());
        pendingAttack = null;
        setState(EnemyState.RECOVER);
    }

    private void spawnProjectile(LivingEntity target, float dmg) {
        if (!(entity.getWorld() instanceof ServerWorld sw)) return;
        Vec3d dir = target.getPos().subtract(entity.getPos()).normalize();
        com.example.shinobicore.entity.NinjaProjectileEntity proj =
            new com.example.shinobicore.entity.NinjaProjectileEntity(
                sw, entity, dir.multiply(1.2), dmg, 3f, "default", "default", 60);
        proj.setPosition(entity.getX(), entity.getY() + 1.2, entity.getZ());
        sw.spawnEntity(proj);
    }

    private void dealAoeDamage(float dmg, float range) {
        if (!(entity.getWorld() instanceof ServerWorld sw)) return;
        Box aoe = new Box(entity.getBlockPos()).expand(range);
        for (var e : sw.getOtherEntities(entity, aoe)) {
            if (e instanceof LivingEntity liv && e != entity) {
                liv.damage(entity.getDamageSources().mobAttack(entity), dmg);
            }
        }
        sw.spawnParticles(ParticleTypes.EXPLOSION,
            entity.getX(), entity.getY(), entity.getZ(), 3, range/2, 1, range/2, 0.01);
    }

    private void tickBlock() {
        // Block is handled in damage() override.
        // Here we just count down block duration.
        if (stateTimer > 40) {
            setState(EnemyState.RECOVER);
        }
    }

    private void tickDash() {
        // Dash: quick movement toward target
        LivingEntity target = entity.getTarget();
        if (target != null && target.isAlive()) {
            Vec3d dir = target.getPos().subtract(entity.getPos()).normalize();
            entity.setVelocity(dir.x * 0.8, 0.1, dir.z * 0.8);
            entity.velocityDirty = true;
        }
        dashCooldown = DASH_COOLDOWN;
        if (stateTimer > 10) {
            setState(EnemyState.RECOVER);
        }
    }

    private void tickKawarimi() {
        // Kawarimi: teleport to nearby location
        if (stateTimer == 1) {
            performKawarimi();
        }
        if (stateTimer > 15) {
            setState(EnemyState.APPROACH);
        }
    }

    private void performKawarimi() {
        if (!(entity.getWorld() instanceof ServerWorld sw)) return;
        // Spawn log visual at current position
        sw.spawnParticles(ParticleTypes.POOF,
            entity.getX(), entity.getY(), entity.getZ(), 15, 0.3, 0.3, 0.3, 0.05);
        // Teleport to nearby location
        double angle = entity.getWorld().getRandom().nextDouble() * Math.PI * 2;
        double dist = 5 + entity.getWorld().getRandom().nextDouble() * 5;
        double newX = entity.getX() + Math.cos(angle) * dist;
        double newZ = entity.getZ() + Math.sin(angle) * dist;
        entity.teleport(newX, entity.getY(), newZ);
        kawarimiCooldown = KAWARIMI_COOLDOWN;
        sw.playSound(null, entity.getBlockPos(),
            net.minecraft.sound.SoundEvents.ENTITY_ENDERMAN_TELEPORT,
            SoundCategory.HOSTILE, 1.0f, 1.0f);
    }

    private void tickRecover() {
        if (stateTimer >= RECOVER_DURATION) {
            setState(EnemyState.APPROACH);
        }
    }

    private void tickFlee() {
        // Move away from target
        LivingEntity target = entity.getTarget();
        if (target != null) {
            Vec3d away = entity.getPos().subtract(target.getPos()).normalize();
            entity.setVelocity(away.x * 0.4, 0, away.z * 0.4);
            entity.velocityDirty = true;
        }
        if (stateTimer > 60 || entity.getHealth() > entity.getMaxHealth() * 0.3f) {
            setState(EnemyState.APPROACH);
        }
    }

    // === PUBLIC METHODS (called from entity) ===

    public void setState(EnemyState newState) {
        previousState = currentState;
        currentState = newState;
        stateTimer = 0;
    }

    /**
     * S9-04: Called when entity takes damage. Decides block/kawarimi.
     * Returns true if damage should be reduced/negated.
     */
    public boolean onDamageTaken(float amount) {
        // Kawarimi check
        if (kawarimiCooldown <= 0) {
            float chance = entity.getRank().getKawarimiChance();
            if (entity.getWorld().getRandom().nextFloat() < chance) {
                setState(EnemyState.KAWARIMI);
                return true; // Negate damage
            }
        }

        // Block check
        if (currentState == EnemyState.APPROACH || currentState == EnemyState.IDLE) {
            if (entity.getBlockStamina() > 0 && blockHitCount < BLOCK_MAX_HITS) {
                setState(EnemyState.BLOCK);
                blockHitCount++;
                entity.setBlockStamina(entity.getBlockStamina() - amount * 0.5f);
                return true; // Reduce damage
            }
        }

        return false;
    }

    /**
     * S9-05: Trigger dash.
     */
    public void triggerDash() {
        if (dashCooldown <= 0) {
            setState(EnemyState.DASH);
        }
    }

    /**
     * Reset block hit count (when block breaks).
     */
    public void resetBlock() {
        blockHitCount = 0;
    }

    public boolean isBlockBroken() {
        return blockHitCount >= BLOCK_MAX_HITS || entity.getBlockStamina() <= 0;
    }
}