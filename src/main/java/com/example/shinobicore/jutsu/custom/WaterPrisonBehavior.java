package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

/**
 * Water Prison Technique - traps enemy in a 3x3x3 water sphere
 * Enemy cannot move for 30 seconds unless they use Kawarimi
 */
public class WaterPrisonBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float range = params.has("range") ? params.get("range").getAsFloat() : 10f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.5f; // 3 block diameter
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 600; // 30 seconds = 600 ticks
        boolean fromTarget = params.has("fromTarget") && params.get("fromTarget").getAsBoolean();
        
        Vec3d look = player.getRotationVector();
        Vec3d start = player.getEyePos();
        Vec3d targetPos = start.add(look.multiply(range));
        
        // Find target entity
        LivingEntity target = null;
        if (fromTarget) {
            // Look at crosshair target
            target = findCrosshairTarget(player, range);
        } else {
            // Closest enemy in range
            target = findClosestEnemy(world, start, range, player);
        }
        
        if (target == null) {
            player.sendMessage(net.minecraft.text.Text.literal("§cNo valid target!"), false);
            return;
        }
        
        // Trap the target
        Vec3d prisonCenter = target.getPos().add(0, target.getHeight() / 2, 0);
        
        // Create water prison visual (3x3x3 sphere)
        spawnWaterPrisonParticles(world, prisonCenter, radius);
        
        // Apply imprisonment effect
        TickScheduler.schedule(world, 1, 2, duration, w -> {
            if (target.isRemoved() || !target.isAlive()) return;
            
            // Check if target is still in prison area
            double dist = target.getPos().distanceTo(prisonCenter);
            if (dist > radius + 1) {
                // Target escaped (e.g., Kawarimi)
                return;
            }
            
            // Apply heavy slowness and prevent jumping
            target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 5, 255, false, false, false));
            target.addStatusEffect(new StatusEffectInstance(StatusEffects.LEVITATION, 5, -10, false, false, false));
            target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, 5, 1, false, false, false));
            
            // Reset velocity to keep them in place
            target.setVelocity(0, 0, 0);
            target.velocityModified = true;
            
            // Deal small damage over time
            target.damage(player.getDamageSources().magic(), damage * 0.1f);
            
            // Continue particles
            spawnWaterPrisonParticles(w, prisonCenter, radius);
        });
        
        // Final release
        TickScheduler.schedule(world, duration + 10, 1, 1, w -> {
            if (target != null && target.isAlive()) {
                target.removeStatusEffect(StatusEffects.SLOWNESS);
                target.removeStatusEffect(StatusEffects.LEVITATION);
                target.removeStatusEffect(StatusEffects.WEAKNESS);
            }
        });
        
        player.sendMessage(net.minecraft.text.Text.literal("§b✦ Water Prison activated!"), false);
    }
    
    private LivingEntity findCrosshairTarget(ServerPlayerEntity player, float range) {
        Vec3d start = player.getEyePos();
        Vec3d look = player.getRotationVector();
        Vec3d end = start.add(look.multiply(range));
        
        Entity closest = null;
        double closestDist = Double.MAX_VALUE;
        
        for (Entity e : player.getWorld().getOtherEntities(player, new Box(start, end).expand(2))) {
            if (e instanceof LivingEntity liv && !liv.equals(player)) {
                double dist = liv.getPos().distanceTo(start);
                if (dist < closestDist && dist <= range) {
                    closestDist = dist;
                    closest = e;
                }
            }
        }
        
        return closest instanceof LivingEntity ? (LivingEntity) closest : null;
    }
    
    private LivingEntity findClosestEnemy(ServerWorld world, Vec3d from, float range, ServerPlayerEntity caster) {
        LivingEntity best = null;
        double bestDist = Double.MAX_VALUE;
        
        for (Entity e : world.getOtherEntities(caster, new Box(from, from).expand(range))) {
            if (e instanceof LivingEntity liv && !liv.equals(caster)) {
                double dist = liv.getPos().distanceTo(from);
                if (dist < bestDist) {
                    bestDist = dist;
                    best = liv;
                }
            }
        }
        
        return best;
    }
    
    private void spawnWaterPrisonParticles(ServerWorld world, Vec3d center, float radius) {
        // Spawn water droplet particles in sphere pattern
        int particleCount = 40;
        for (int i = 0; i < particleCount; i++) {
            double theta = Math.random() * Math.PI * 2;
            double phi = Math.acos(2 * Math.random() - 1);
            double r = radius * Math.cbrt(Math.random());
            
            double x = center.x + r * Math.sin(phi) * Math.cos(theta);
            double y = center.y + r * Math.sin(phi) * Math.sin(theta);
            double z = center.z + r * Math.cos(phi);
            
            world.spawnParticles(ParticleTypes.WATER_SPLASH, x, y, z, 1, 0, 0, 0, 0.1);
        }
        
        // Add bubble particles inside
        for (int i = 0; i < 8; i++) {
            double ox = (Math.random() - 0.5) * radius * 1.5;
            double oy = (Math.random() - 0.5) * radius * 1.5;
            double oz = (Math.random() - 0.5) * radius * 1.5;
            world.spawnParticles(ParticleTypes.BUBBLE, center.x + ox, center.y + oy, center.z + oz, 1, 0, 0, 0, 0.05);
        }
    }
}
