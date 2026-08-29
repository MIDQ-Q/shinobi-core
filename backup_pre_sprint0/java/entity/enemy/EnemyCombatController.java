package com.example.shinobicore.entity.enemy;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.jutsu.data.JutsuRegistry;
import com.example.shinobicore.util.ColorHelper;
import com.google.gson.JsonObject;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.JsonHelper;
import net.minecraft.util.math.Vec3d;

import java.util.Random;

/**
 * FSM combat controller for rogue ninja enemies.
 * HLD: Section 5 (IDLE..FLEE, kawarimi, block, JSON jutsu casting).
 * Performance: decisions throttled, no per-tick allocations.
 */
public final class EnemyCombatController {

    private final NinjaEnemyEntity enemy;
    private final Random random = new Random();

    private EnemyState state = EnemyState.IDLE;
    private int stateTicks = 0;
    private int jutsuCooldown = 60;
    private int kawarimiCooldown = 0;
    private int blockTicks = 0;
    private ServerPlayerEntity target;

    public EnemyCombatController(NinjaEnemyEntity enemy) {
        this.enemy = enemy;
    }

    public EnemyState getState() { return state; }

    public boolean isBlocking() {
        return state == EnemyState.BLOCK && blockTicks > 0;
    }

    public void requestKawarimi() {
        if (kawarimiCooldown <= 0 && state != EnemyState.KAWARIMI) {
            setState(EnemyState.KAWARIMI);
        }
    }

    public void tick(ServerWorld world) {
        stateTicks++;
        if (jutsuCooldown > 0) jutsuCooldown--;
        if (kawarimiCooldown > 0) kawarimiCooldown--;

        refreshTarget(world);

        if (state == EnemyState.IDLE || state == EnemyState.PATROL) {
            handlePassive();
        } else if (state == EnemyState.APPROACH) {
            handleApproach(world);
        } else if (state == EnemyState.TELEGRAPH) {
            handleTelegraph();
        } else if (state == EnemyState.ATTACK) {
            handleAttack();
        } else if (state == EnemyState.BLOCK) {
            handleBlock();
        } else if (state == EnemyState.KAWARIMI) {
            handleKawarimi(world);
        } else if (state == EnemyState.FLEE) {
            handleFlee();
        }
    }

    private void setState(EnemyState next) {
        this.state = next;
        this.stateTicks = 0;
    }

    private void refreshTarget(ServerWorld world) {
        PlayerEntity closest = world.getClosestPlayer(
            enemy.getX(), enemy.getY(), enemy.getZ(), 16.0, null);
        this.target = null;
        if (closest instanceof ServerPlayerEntity sp && !sp.isSpectator()) {
            this.target = sp;
        }
    }

    private void handlePassive() {
        if (target != null) {
            setState(EnemyState.APPROACH);
            return;
        }
        if (state == EnemyState.IDLE && stateTicks > 100) {
            setState(EnemyState.PATROL);
        }
    }

    private void handleApproach(ServerWorld world) {
        if (target == null) {
            setState(EnemyState.IDLE);
            return;
        }

        if (enemy.getHealth() < enemy.getMaxHealth() * 0.2f
                && random.nextInt(100) < 2) {
            setState(EnemyState.FLEE);
            return;
        }

        if (enemy.squaredDistanceTo(target.getPos()) < 6.25) {
            setState(EnemyState.TELEGRAPH);
            return;
        }

        enemy.getMoveControl().moveTo(
            target.getX(), target.getY(), target.getZ(), 1.0);

        if (jutsuCooldown <= 0) {
            if (castRangedJutsu(world)) {
                jutsuCooldown = 80 + random.nextInt(40);
            } else {
                jutsuCooldown = 20;
            }
        }

        if (stateTicks > 300) {
            setState(EnemyState.IDLE);
        }
    }

    private void handleTelegraph() {
        enemy.setVelocity(0.0, enemy.getVelocity().y, 0.0);
        if (stateTicks > 12) {
            setState(EnemyState.ATTACK);
        }
    }

    private void handleAttack() {
        if (stateTicks == 1) {
            if (target != null && enemy.squaredDistanceTo(target.getPos()) < 9.0) {
                target.damage(target.getDamageSources().mobAttack(enemy),
                    enemy.getRank().getMeleeDamage());
            }
        }
        if (stateTicks > 6) {
            if (random.nextInt(100) < 25) {
                setState(EnemyState.BLOCK);
                blockTicks = 20;
            } else {
                setState(EnemyState.APPROACH);
            }
        }
    }

    private void handleBlock() {
        blockTicks--;
        if (blockTicks <= 0) {
            setState(EnemyState.APPROACH);
        }
    }

    private void handleKawarimi(ServerWorld world) {
        if (stateTicks == 1) {
            Vec3d old = enemy.getPos();
            double angle = random.nextDouble() * Math.PI * 2.0;
            Vec3d next = old.add(Math.cos(angle) * 5.0, 0.0, Math.sin(angle) * 5.0);

            world.addParticle(ParticleTypes.POOF, old.x, old.y + 1.0, old.z, 0.0, 0.2, 0.0);
            enemy.setPosition(next.x, next.y, next.z);
            enemy.fallDistance = 0.0f;
            world.addParticle(ParticleTypes.POOF, next.x, next.y + 1.0, next.z, 0.0, 0.2, 0.0);
            kawarimiCooldown = 200;
        }
        if (stateTicks > 4) {
            setState(EnemyState.FLEE);
        }
    }

    private void handleFlee() {
        if (target == null) {
            setState(EnemyState.IDLE);
            return;
        }
        Vec3d away = enemy.getPos().subtract(target.getPos());
        Vec3d flat = new Vec3d(away.x, 0.0, away.z);
        if (flat.lengthSquared() > 0.001) {
            flat = flat.normalize();
            enemy.getMoveControl().moveTo(
                enemy.getX() + flat.x * 8.0, enemy.getY(),
                enemy.getZ() + flat.z * 8.0, 1.2);
        }
        if (stateTicks > 60) {
            setState(EnemyState.APPROACH);
        }
    }

    /**
     * Cast a JSON-defined jutsu from the rank pool (HLD Section 5).
     */
    private boolean castRangedJutsu(ServerWorld world) {
        String[] pool = enemy.getRank().getJutsus();
        if (pool.length == 0 || target == null) {
            return false;
        }

        String id = pool[random.nextInt(pool.length)];
        JutsuDefinition def = JutsuRegistry.get(id);
        if (def == null) {
            return false;
        }

        JsonObject params = def.params();
        float speed = JsonHelper.getFloat(params, "speed", 1.2f);
        float radius = JsonHelper.getFloat(params, "radius", 1.0f);
        String particle = JsonHelper.getString(params, "particle", "flame");
        int burn = JsonHelper.getInt(params, "burn_seconds", 0);
        int lifetime = JsonHelper.getInt(params, "lifetime", 80);
        boolean gravity = JsonHelper.getBoolean(params, "gravity", false);
        int color = ColorHelper.parse(JsonHelper.getString(def.visuals(), "color", "#FFFFFF"));

        Vec3d dir = target.getEyePos().subtract(enemy.getEyePos()).normalize();
        Vec3d spawn = enemy.getEyePos();

        NinjaProjectileEntity proj = new NinjaProjectileEntity(
            enemy.getWorld(), enemy, def.baseDamage(), radius,
            particle, color, gravity, burn, lifetime);
        proj.setVelocity(dir.multiply(speed));
        proj.setPosition(spawn.x, spawn.y, spawn.z);
        world.spawnEntity(proj);
        return true;
    }
}