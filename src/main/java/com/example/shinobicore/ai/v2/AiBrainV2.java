package com.example.shinobicore.ai.v2;

import com.example.shinobicore.jutsu.executor.Fx;
import com.example.shinobicore.jutsu.enums.ElementType;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class AiBrainV2 {
    public final MobEntity entity;
    public ServerPlayerEntity target;
    public final AiTierDefinition tier;
    
    public enum State { IDLE, APPROACH, ENGAGE_MELEE, ENGAGE_RANGED, RETREAT, SEEK_COVER }
    public State currentState = State.IDLE;
    
    public int stateTicks = 0;
    public int actionCooldown = 0;
    
    public AiBrainV2(MobEntity entity, AiTierDefinition tier) {
        this.entity = entity;
        this.tier = tier;
    }
    
    public void tick(ServerWorld world) {
        if (entity.isDead() || !entity.isAlive()) return;
        
        stateTicks++;
        if (actionCooldown > 0) actionCooldown--;
        
        if (target == null || !target.isAlive() || target.isDead()) {
            target = findTarget(world);
            if (target == null) { currentState = State.IDLE; return; }
        }
        
        double dist = entity.getPos().distanceTo(target.getPos());
        evaluateAndAct(world, dist);
    }
    
    private ServerPlayerEntity findTarget(ServerWorld world) {
        ServerPlayerEntity best = null;
        double bd = 24.0;
        for (ServerPlayerEntity p : world.getPlayers()) {
            if (p.isAlive() && !p.isSpectator()) {
                double d = p.getPos().distanceTo(entity.getPos());
                if (d < bd) { bd = d; best = p; }
            }
        }
        return best;
    }
    
    private void evaluateAndAct(ServerWorld world, double dist) {
        float hpPercent = entity.getHealth() / entity.getMaxHealth();
        
        if (hpPercent < tier.thresholds.getOrDefault("retreatHealthPercent", 0.1f)) {
            currentState = State.RETREAT;
        } else if (tier.canUseEnvironment && hpPercent < tier.thresholds.getOrDefault("coverHealthPercent", 0.4f)) {
            currentState = State.SEEK_COVER;
        }
        
        switch (currentState) {
            case IDLE:
            case APPROACH:
                if (dist > 2.5) {
                    moveTowards(target.getPos(), 1.0);
                    currentState = State.APPROACH;
                } else {
                    currentState = State.ENGAGE_MELEE;
                }
                break;
                
            case ENGAGE_MELEE:
                if (dist > 3.5) { currentState = State.APPROACH; } 
                else if (actionCooldown <= 0) {
                    performMeleeAttack();
                    actionCooldown = 20;
                }
                break;
                
            case ENGAGE_RANGED:
                if (dist < 4.0 || dist > 16.0) { currentState = State.APPROACH; } 
                else if (actionCooldown <= 0) {
                    performRangedAttack(world);
                    actionCooldown = 40;
                }
                break;
                
            case RETREAT:
                Vec3d away = entity.getPos().subtract(target.getPos()).normalize().multiply(5);
                moveTowards(entity.getPos().add(away), 1.2);
                if (hpPercent > tier.thresholds.getOrDefault("retreatHealthPercent", 0.1f) + 0.2f) {
                    currentState = State.APPROACH;
                }
                break;
                
            case SEEK_COVER:
                Vec3d coverPos = AiEnvironmentScanner.findCover(world, entity, target);
                if (coverPos != null) {
                    moveTowards(coverPos, 1.1);
                    if (entity.getPos().distanceTo(coverPos) < 2.0) { currentState = State.ENGAGE_RANGED; }
                } else { currentState = State.RETREAT; }
                break;
        }
        
        if (tier.canInterruptCasts && AiReactionSystem.isPlayerCasting(target)) {
            if (dist < 10.0 && actionCooldown <= 0) {
                performInterrupt(world);
                actionCooldown = 60;
            }
        }
    }
    
    private void moveTowards(Vec3d pos, double speed) {
        entity.getNavigation().startMovingTo(pos.x, pos.y, pos.z, speed * tier.speedMultiplier);
    }
    
    private void performMeleeAttack() {
        if (target != null && entity.getPos().distanceTo(target.getPos()) < 3.0) {
            target.damage(entity.getDamageSources().mobAttack(entity), 5.0f * tier.damageMultiplier);
        }
    }
    
    private void performRangedAttack(ServerWorld world) {
        if (target != null) {
            target.damage(entity.getDamageSources().magic(), 3.0f * tier.damageMultiplier);
            Fx.elementBurst(world, target.getPos(), ElementType.NONE, 5);
        }
    }
    
    private void performInterrupt(ServerWorld world) {
        if (target != null) {
            Vec3d dir = target.getPos().subtract(entity.getPos()).normalize();
            entity.addVelocity(dir.x * 0.8, 0.2, dir.z * 0.8);
            entity.velocityModified = true;
            Fx.elementBurst(world, entity.getPos(), ElementType.WIND, 10);
        }
    }
}