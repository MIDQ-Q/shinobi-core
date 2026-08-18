package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

/**
 * Water Release: Maelstrom Vortex
 * Creates a vortex that pulls enemies towards the caster
 * Only works when player is standing on water
 */
public class MaelstromBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        // Check if player is on water
        boolean onWater = isPlayerOnWater(player);
        if (!onWater) {
            player.sendMessage(Text.literal("§cMust be standing on water!"), false);
            return;
        }
        
        float range = params.has("range") ? params.get("range").getAsFloat() : 15f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 8f;
        float pullStrength = params.has("pullStrength") ? params.get("pullStrength").getAsFloat() : 0.4f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 100;
        
        Vec3d center = player.getPos();
        
        // Create vortex visual
        spawnVortexParticles(world, center, radius);
        
        // Pull enemies continuously
        TickScheduler.schedule(world, 5, 5, duration, w -> {
            if (player.isRemoved() || !player.isAlive()) return;
            
            // Continue particles
            spawnVortexParticles(w, center, radius);
            
            // Find and pull enemies
            for (Entity e : w.getOtherEntities(player, new Box(center, center).expand(range))) {
                if (e instanceof LivingEntity target && !target.equals(player)) {
                    double dist = target.getPos().distanceTo(center);
                    if (dist <= range && dist > 2.0) {
                        // Pull towards player
                        Vec3d direction = center.subtract(target.getPos()).normalize();
                        target.addVelocity(direction.multiply(pullStrength));
                        target.velocityModified = true;
                        
                        // Add swirling motion
                        double angle = Math.atan2(target.getZ() - center.z, target.getX() - center.x);
                        double swirlX = -Math.sin(angle) * 0.15;
                        double swirlZ = Math.cos(angle) * 0.15;
                        target.addVelocity(swirlX, 0, swirlZ);
                        target.velocityModified = true;
                        
                        // Deal small damage over time
                        target.damage(player.getDamageSources().magic(), damage * 0.05f);
                    }
                }
            }
        });
        
        player.sendMessage(Text.literal("§b✦ Maelstrom Vortex activated!"), false);
    }
    
    private boolean isPlayerOnWater(ServerPlayerEntity player) {
        // Check if player is standing on water or in water
        int x = (int) Math.floor(player.getX());
        int y = (int) Math.floor(player.getY() - 0.5);
        int z = (int) Math.floor(player.getZ());
        
        return player.getWorld().getBlockState(new net.minecraft.util.math.BlockPos(x, y, z)).isOf(Blocks.WATER) ||
               player.getWorld().getBlockState(new net.minecraft.util.math.BlockPos(x, y + 1, z)).isOf(Blocks.WATER) ||
               player.isTouchingWater();
    }
    
    private void spawnVortexParticles(ServerWorld world, Vec3d center, float radius) {
        int particleCount = 30;
        for (int i = 0; i < particleCount; i++) {
            double angle = (i / (double) particleCount) * Math.PI * 2;
            double r = Math.random() * radius;
            
            double x = center.x + Math.cos(angle) * r;
            double z = center.z + Math.sin(angle) * r;
            double y = center.y + Math.random() * 2;
            
            world.spawnParticles(ParticleTypes.WATER_SPLASH, x, y, z, 1, 0, 0.1, 0, 0.05);
            world.spawnParticles(ParticleTypes.BUBBLE, x, y, z, 1, 0, 0.05, 0, 0.02);
        }
    }
}
