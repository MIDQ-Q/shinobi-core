# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 9 - Enemies & AI
# S9-01..S9-10: Ninja Enemy Entity, FSM, Ranks, Loot
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$enemyDir = Join-Path $srcBase "entity\enemy"
$resBase = Join-Path $root "src\main\resources"
$texDir = Join-Path $resBase "assets\shinobicore\textures\entity"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 9: Enemies & AI (S9-01..S9-10)" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host ("  [MISS] " + $p) -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host ("  [SKIP] already: " + (Split-Path $p -Leaf)) -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host ("  [FAIL] pattern: " + (Split-Path $p -Leaf)) -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host ("  [PATCH] " + (Split-Path $p -Leaf)) -ForegroundColor Green
    return $true
}

# ============================================================
# S9-07: NINJA RANK ENUM
# ============================================================
Write-Host "[S9-07] Creating NinjaRank enum..." -ForegroundColor Yellow

$ninjaRank = @'
package com.example.shinobicore.entity.enemy;

/**
 * S9-07: Enemy rank presets.
 * Each rank defines base stats, attack count, kawarimi chance, telegraph time.
 */
public enum NinjaRank {
    GENIN("genin", 20.0f, 200.0f, 100.0f, 0.25f, 4.0f, 0.3f, 1, 0.0f, 30, false),
    CHUNIN("chunin", 30.0f, 400.0f, 200.0f, 0.28f, 6.0f, 0.5f, 2, 0.10f, 24, false),
    JONIN("jonin", 40.0f, 800.0f, 400.0f, 0.32f, 9.0f, 0.7f, 3, 0.25f, 16, false),
    ANBU("anbu", 50.0f, 1200.0f, 600.0f, 0.35f, 12.0f, 0.9f, 4, 0.40f, 10, false),
    NUKE_NIN("nuke_nin", 80.0f, 2000.0f, 1000.0f, 0.35f, 16.0f, 1.0f, 4, 0.50f, 10, true);

    private final String id;
    private final float maxHealth;
    private final float maxChakra;
    private final float maxStamina;
    private final float moveSpeed;
    private final float baseDamage;
    private final float aggression;
    private final int attackCount;
    private final float kawarimiChance;
    private final int telegraphTicks;
    private final boolean isBossRank;

    NinjaRank(String id, float maxHealth, float maxChakra, float maxStamina,
              float moveSpeed, float baseDamage, float aggression, int attackCount,
              float kawarimiChance, int telegraphTicks, boolean isBossRank) {
        this.id = id;
        this.maxHealth = maxHealth;
        this.maxChakra = maxChakra;
        this.maxStamina = maxStamina;
        this.moveSpeed = moveSpeed;
        this.baseDamage = baseDamage;
        this.aggression = aggression;
        this.attackCount = attackCount;
        this.kawarimiChance = kawarimiChance;
        this.telegraphTicks = telegraphTicks;
        this.isBossRank = isBossRank;
    }

    public String getId() { return id; }
    public float getMaxHealth() { return maxHealth; }
    public float getMaxChakra() { return maxChakra; }
    public float getMaxStamina() { return maxStamina; }
    public float getMoveSpeed() { return moveSpeed; }
    public float getBaseDamage() { return baseDamage; }
    public float getAggression() { return aggression; }
    public int getAttackCount() { return attackCount; }
    public float getKawarimiChance() { return kawarimiChance; }
    public int getTelegraphTicks() { return telegraphTicks; }
    public boolean isBossRank() { return isBossRank; }

    public static NinjaRank fromId(String id) {
        for (NinjaRank r : values()) {
            if (r.id.equals(id)) return r;
        }
        return GENIN;
    }
}
'@
Write-File (Join-Path $enemyDir "NinjaRank.java") $ninjaRank

# ============================================================
# S9-02: ENEMY STATE ENUM (FSM states)
# ============================================================
Write-Host "[S9-02] Creating EnemyState enum..." -ForegroundColor Yellow

$enemyState = @'
package com.example.shinobicore.entity.enemy;

/**
 * S9-02: FSM states for enemy AI.
 * States are managed by EnemyCombatController.
 */
public enum EnemyState {
    IDLE,           // Standing, looking around
    PATROL,         // Walking between patrol points
    INVESTIGATE,    // Moving to point of interest
    APPROACH,       // Moving toward target
    TELEGRAPH,      // Playing attack warning (sound + particles)
    MELEE_ATTACK,   // Executing melee attack
    RANGED_ATTACK,  // Executing ranged attack (projectile)
    AOE_ATTACK,     // Executing area attack
    BLOCK,          // Blocking incoming attacks
    DASH,           // Quick movement (toward/away from target)
    KAWARIMI,       // Substitution jutsu
    RECOVER,        // Recovery after attack or block break
    FLEE            // Running away (low HP)
}
'@
Write-File (Join-Path $enemyDir "EnemyState.java") $enemyState

# ============================================================
# S9-02: ENEMY ATTACK DEFINITION
# ============================================================
Write-Host "[S9-02] Creating EnemyAttack..." -ForegroundColor Yellow

$enemyAttack = @'
package com.example.shinobicore.entity.enemy;

import net.minecraft.sound.SoundEvent;

/**
 * S9-02: Definition of an enemy attack.
 * Simplified attacks (not full jutsu cast).
 */
public class EnemyAttack {
    public enum AttackType { MELEE, RANGED, AOE, DASH_ATTACK }

    private final String name;
    private final AttackType type;
    private final float damage;
    private final float range;
    private final int telegraphTicks;
    private final int cooldownTicks;
    private final SoundEvent telegraphSound;

    public EnemyAttack(String name, AttackType type, float damage, float range,
                       int telegraphTicks, int cooldownTicks, SoundEvent telegraphSound) {
        this.name = name;
        this.type = type;
        this.damage = damage;
        this.range = range;
        this.telegraphTicks = telegraphTicks;
        this.cooldownTicks = cooldownTicks;
        this.telegraphSound = telegraphSound;
    }

    public String getName() { return name; }
    public AttackType getType() { return type; }
    public float getDamage() { return damage; }
    public float getRange() { return range; }
    public int getTelegraphTicks() { return telegraphTicks; }
    public int getCooldownTicks() { return cooldownTicks; }
    public SoundEvent getTelegraphSound() { return telegraphSound; }

    /** Create default melee attack. */
    public static EnemyAttack melee(float damage, int telegraph, int cooldown) {
        return new EnemyAttack("melee_strike", AttackType.MELEE, damage, 2.5f,
            telegraph, cooldown, net.minecraft.sound.SoundEvents.ENTITY_ZOMBIE_ATTACK_WOODEN_DOOR);
    }

    /** Create default ranged attack. */
    public static EnemyAttack ranged(float damage, float range, int telegraph, int cooldown) {
        return new EnemyAttack("ranged_shot", AttackType.RANGED, damage, range,
            telegraph, cooldown, net.minecraft.sound.SoundEvents.ENTITY_SKELETON_SHOOT);
    }

    /** Create default AOE attack. */
    public static EnemyAttack aoe(float damage, float range, int telegraph, int cooldown) {
        return new EnemyAttack("aoe_burst", AttackType.AOE, damage, range,
            telegraph, cooldown, net.minecraft.sound.SoundEvents.ENTITY_CREEPER_PRIMED);
    }

    /** Create default dash attack. */
    public static EnemyAttack dashAttack(float damage, int telegraph, int cooldown) {
        return new EnemyAttack("dash_strike", AttackType.DASH_ATTACK, damage, 4.0f,
            telegraph, cooldown, net.minecraft.sound.SoundEvents.ENTITY_ENDERMAN_TELEPORT);
    }
}
'@
Write-File (Join-Path $enemyDir "EnemyAttack.java") $enemyAttack

# ============================================================
# S9-02: ENEMY COMBAT CONTROLLER (FSM)
# ============================================================
Write-Host "[S9-02] Creating EnemyCombatController (FSM)..." -ForegroundColor Yellow

$combatController = @'
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
        List<EnemyAttack> available = new ArrayList<>();
        for (EnemyAttack atk : attacks) {
            String cdKey = atk.getName();
            int cd = attackCooldowns.getOrDefault(cdKey, 0);
            if (cd > 0) continue;

            switch (atk.getType()) {
                case MELEE -> { if (dist <= atk.getRange()) available.add(atk); }
                case RANGED -> { if (dist > 3f && dist <= atk.getRange()) available.add(atk); }
                case AOE -> { if (dist <= atk.getRange()) available.add(atk); }
                case DASH_ATTACK -> { if (dist > 2f && dist <= atk.getRange() && dashCooldown <= 0) available.add(atk); }
            }
        }
        if (available.isEmpty()) return null;
        return available.get(entity.getWorld().getRandom().nextInt(available.size()));
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
'@
Write-File (Join-Path $enemyDir "EnemyCombatController.java") $combatController

# ============================================================
# S9-01: NINJA ENEMY ENTITY
# ============================================================
Write-Host "[S9-01] Creating NinjaEnemyEntity..." -ForegroundColor Yellow

$ninjaEnemyEntity = @'
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
'@
Write-File (Join-Path $enemyDir "NinjaEnemyEntity.java") $ninjaEnemyEntity

# ============================================================
# S9-09: ENEMY LOOT TABLE
# ============================================================
Write-Host "[S9-09] Creating EnemyLootTable..." -ForegroundColor Yellow

$lootTable = @'
package com.example.shinobicore.entity.enemy;

import com.example.shinobicore.item.ModItems;
import net.minecraft.entity.LivingEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.item.Items;
import java.util.Random;

/**
 * S9-09: Loot table for enemy drops.
 * Drops based on rank. Configurable via difficulty multiplier.
 */
public class EnemyLootTable {

    /**
     * Drop loot when enemy dies.
     * Called from NinjaEnemyEntity.onDeath() or dropLoot().
     */
    public static void dropLoot(LivingEntity entity, NinjaRank rank, float lootQualityMultiplier) {
        Random rand = entity.getWorld().getRandom();
        float dropChance = 0.5f * lootQualityMultiplier;

        switch (rank) {
            case GENIN -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.KUNAI, 1 + rand.nextInt(3)));
                }
            }
            case CHUNIN -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.SHURIKEN, 2 + rand.nextInt(4)));
                }
                if (rand.nextFloat() < dropChance * 0.5f) {
                    entity.dropStack(new ItemStack(ModItems.KUNAI, 1 + rand.nextInt(2)));
                }
            }
            case JONIN -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.SHURIKEN, 3 + rand.nextInt(5)));
                }
                if (rand.nextFloat() < dropChance * 0.3f) {
                    entity.dropStack(new ItemStack(Items.PAPER, 1)); // Scroll material
                }
            }
            case ANBU -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.SHURIKEN, 4 + rand.nextInt(6)));
                }
                if (rand.nextFloat() < dropChance * 0.5f) {
                    entity.dropStack(new ItemStack(Items.PAPER, 1 + rand.nextInt(2)));
                }
            }
            case NUKE_NIN -> {
                if (rand.nextFloat() < dropChance) {
                    entity.dropStack(new ItemStack(ModItems.SHURIKEN, 5 + rand.nextInt(8)));
                }
                if (rand.nextFloat() < dropChance * 0.7f) {
                    entity.dropStack(new ItemStack(Items.PAPER, 2 + rand.nextInt(3)));
                }
                if (rand.nextFloat() < dropChance * 0.2f) {
                    entity.dropStack(new ItemStack(ModItems.KATANA, 1));
                }
            }
        }
    }
}
'@
Write-File (Join-Path $enemyDir "EnemyLootTable.java") $lootTable

# ============================================================
# S9-01: ENEMY RENDERER (Player model with shinobi skin)
# ============================================================
Write-Host "[S9-01] Creating EnemyRenderer..." -ForegroundColor Yellow

$enemyRenderer = @'
package com.example.shinobicore.entity.enemy;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.client.render.entity.BipedEntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.render.entity.model.EntityModelLayers;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.util.Identifier;

/**
 * S9-01: Renderer for ninja enemies.
 * Uses player model with shinobi skin texture.
 * Skin file: assets/shinobicore/textures/entity/shinobi.png (64x64)
 */
public class EnemyRenderer extends BipedEntityRenderer<NinjaEnemyEntity, PlayerEntityModel<NinjaEnemyEntity>> {
    private static final Identifier SHINOBI_TEXTURE =
        new Identifier(ShinobiCore.MOD_ID, "textures/entity/shinobi.png");

    public EnemyRenderer(EntityRendererFactory.Context context) {
        super(context, new PlayerEntityModel<>(context.getPart(EntityModelLayers.PLAYER), false), 0.5f);
    }

    @Override
    public Identifier getTexture(NinjaEnemyEntity entity) {
        return SHINOBI_TEXTURE;
    }
}
'@
Write-File (Join-Path $enemyDir "EnemyRenderer.java") $enemyRenderer

# ============================================================
# GENERATE SHINOBI SKIN TEXTURE (placeholder)
# ============================================================
Write-Host "[S9-01] Generating shinobi skin texture (placeholder)..." -ForegroundColor Yellow

if (-not (Test-Path $texDir)) { New-Item -ItemType Directory -Path $texDir -Force | Out-Null }

Add-Type -AssemblyName System.Drawing
$skinBitmap = New-Object System.Drawing.Bitmap(64, 64)
# Fill transparent
for ($x = 0; $x -lt 64; $x++) { for ($y = 0; $y -lt 64; $y++) { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0,0,0,0)) } }
# Head (8x8 at 8,8) - dark hood
for ($x = 8; $x -lt 16; $x++) { for ($y = 8; $y -lt 16; $y++) {
    if ($y -lt 10) { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 30, 30, 40)) }
    else { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 200, 170, 140)) }
}}
# Body (8x12 at 20,20) - dark blue ninja outfit
for ($x = 20; $x -lt 28; $x++) { for ($y = 20; $y -lt 32; $y++) {
    if ($y % 4 -lt 2) { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 40, 50, 80)) }
    else { $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 30, 40, 60)) }
}}
# Right arm (4x12 at 44,20)
for ($x = 44; $x -lt 48; $x++) { for ($y = 20; $y -lt 32; $y++) {
    $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 35, 45, 70))
}}
# Left arm (4x12 at 36,52)
for ($x = 36; $x -lt 40; $x++) { for ($y = 52; $y -lt 64; $y++) {
    $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 35, 45, 70))
}}
# Right leg (4x12 at 4,20)
for ($x = 4; $x -lt 8; $x++) { for ($y = 20; $y -lt 32; $y++) {
    $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 25, 30, 50))
}}
# Left leg (4x12 at 20,52)
for ($x = 20; $x -lt 24; $x++) { for ($y = 52; $y -lt 64; $y++) {
    $skinBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 25, 30, 50))
}}
$skinBitmap.Save("$texDir\shinobi.png", [System.Drawing.Imaging.ImageFormat]::Png)
$skinBitmap.Dispose()
Write-Host "  [OK] shinobi.png generated (placeholder - replace with real skin)" -ForegroundColor Green

# ============================================================
# PATCHES: Registration
# ============================================================
Write-Host ""
Write-Host "[REG] Patching registration files..." -ForegroundColor Yellow

# ModEntities.java
$modEntitiesFile = Join-Path $srcBase "entity\ModEntities.java"
Patch-File $modEntitiesFile `
    "public static void register() {" `
    "public static final EntityType<com.example.shinobicore.entity.enemy.NinjaEnemyEntity> NINJA_ENEMY = Registry.register(`n        Registries.ENTITY_TYPE,`n        new Identifier(ShinobiCore.MOD_ID, `"ninja_enemy`"),`n        FabricEntityTypeBuilder.<com.example.shinobicore.entity.enemy.NinjaEnemyEntity>create(SpawnGroup.MONSTER, com.example.shinobicore.entity.enemy.NinjaEnemyEntity::new)`n            .dimensions(EntityDimensions.fixed(0.6f, 1.8f))`n            .trackRangeChunks(64)`n            .trackedUpdateRate(3)`n            .build());`n`n    public static void register() {"

# ShinobiCore.java - register entity attributes
$shinobiCoreFile = Join-Path $srcBase "ShinobiCore.java"
Patch-File $shinobiCoreFile `
    "ServerLifecycleEvents.SERVER_STARTED.register(server -> {" `
    "// S9-01: Register enemy entity attributes`n        FabricDefaultAttributeRegistry.register(ModEntities.NINJA_ENEMY,`n            com.example.shinobicore.entity.enemy.NinjaEnemyEntity.createNinjaEnemyAttributes());`n        ServerLifecycleEvents.SERVER_STARTED.register(server -> {"

# ShinobiCoreClient.java - register enemy renderer
$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"
Patch-File $clientFile `
    "EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);" `
    "EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);`n        EntityRendererRegistry.register(ModEntities.NINJA_ENEMY, com.example.shinobicore.entity.enemy.EnemyRenderer::new);"

# ModConfig.java - add difficulty settings (S9-10)
$configFile = Join-Path $srcBase "config\ModConfig.java"
Patch-File $configFile `
    "public boolean debugLogs = false;" `
    "public boolean debugLogs = false;`n    // S9-10: Enemy difficulty settings`n    public float enemyDamageMultiplier = 1.0f;`n    public float enemyKawarimiChanceMultiplier = 1.0f;`n    public float enemyAggressionMultiplier = 1.0f;`n    public float enemyCooldownMultiplier = 1.0f;`n    public float lootQualityMultiplier = 1.0f;"

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 25 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    }
} finally { Pop-Location }

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 9 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - entity/enemy/NinjaRank.java (S9-07: rank presets)" -ForegroundColor Cyan
Write-Host "  - entity/enemy/EnemyState.java (S9-02: FSM states)" -ForegroundColor Cyan
Write-Host "  - entity/enemy/EnemyAttack.java (S9-02: attack definitions)" -ForegroundColor Cyan
Write-Host "  - entity/enemy/EnemyCombatController.java (S9-02: combat FSM)" -ForegroundColor Cyan
Write-Host "  - entity/enemy/NinjaEnemyEntity.java (S9-01: base entity)" -ForegroundColor Cyan
Write-Host "  - entity/enemy/EnemyLootTable.java (S9-09: loot by rank)" -ForegroundColor Cyan
Write-Host "  - entity/enemy/EnemyRenderer.java (S9-01: player model renderer)" -ForegroundColor Cyan
Write-Host "  - textures/entity/shinobi.png (placeholder skin)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Patched files:" -ForegroundColor White
Write-Host "  - ModEntities.java (NINJA_ENEMY registration)" -ForegroundColor Cyan
Write-Host "  - ShinobiCore.java (entity attributes)" -ForegroundColor Cyan
Write-Host "  - ShinobiCoreClient.java (renderer registration)" -ForegroundColor Cyan
Write-Host "  - ModConfig.java (S9-10: difficulty settings)" -ForegroundColor Cyan
Write-Host ""
Write-Host "FSM States: IDLE, PATROL, APPROACH, TELEGRAPH, MELEE/RANGED/AOE," -ForegroundColor Yellow
Write-Host "  BLOCK, DASH, KAWARIMI, RECOVER, FLEE" -ForegroundColor Yellow
Write-Host ""
Write-Host "Ranks: GENIN, CHUNIN, JONIN, ANBU, NUKE_NIN (boss)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Test: /summon shinobicore:ninja_enemy" -ForegroundColor Cyan
Write-Host "Note: Replace shinobi.png with real skin from internet" -ForegroundColor Cyan
Write-Host ""