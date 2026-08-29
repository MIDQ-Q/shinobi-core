package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

/**
 * Mud Wave Technique - creates a 5x5 area of darkened earth with cobwebs for slowness
 */
public class MudWaveBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float range = params.has("range") ? params.get("range").getAsFloat() : 8f;
        int size = params.has("size") ? params.get("size").getAsInt() : 5; // 5x5 area
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 100; // 5 seconds
        int slownessDuration = params.has("slownessDuration") ? params.get("slownessDuration").getAsInt() : 60;
        int slownessAmplifier = params.has("slownessAmplifier") ? params.get("slownessAmplifier").getAsInt() : 2;
        
        Vec3d look = player.getRotationVector();
        Vec3d start = player.getPos().add(look.multiply(range));
        
        // Create mud wave area in front of player
        int halfSize = size / 2;
        BlockPos.Mutable mutablePos = new BlockPos.Mutable();
        
        // Darken earth blocks and create invisible slowdown zone
        for (int dx = -halfSize; dx <= halfSize; dx++) {
            for (int dz = -halfSize; dz <= halfSize; dz++) {
                BlockPos pos = BlockPos.ofFloored(start.x + dx, start.y - 1, start.z + dz);
                
                // Check if block is earth/grass/dirt
                if (world.getBlockState(pos).isOf(Blocks.GRASS_BLOCK) || 
                    world.getBlockState(pos).isOf(Blocks.DIRT) ||
                    world.getBlockState(pos).isOf(Blocks.COARSE_DIRT)) {
                    
                    // Replace with coarse dirt (darker appearance)
                    world.setBlockState(pos, Blocks.COARSE_DIRT.getDefaultState());
                    
                    // Schedule restoration after duration
                    final BlockPos restorePos = pos.toImmutable();
                    TickScheduler.schedule(world, duration, 1, 1, w -> {
                        if (w.getBlockState(restorePos).isOf(Blocks.COARSE_DIRT)) {
                            w.setBlockState(restorePos, Blocks.GRASS_BLOCK.getDefaultState());
                        }
                    });
                }
            }
        }
        
        // Apply slowness to enemies in the area
        Box effectBox = new Box(start.add(-halfSize, 0, -halfSize), start.add(halfSize, 2, halfSize));
        
        TickScheduler.schedule(world, 1, 10, duration / 10, w -> {
            for (Entity e : w.getOtherEntities(player, effectBox)) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    // Apply slowness (simulates being stuck in mud/cobwebs)
                    liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, slownessDuration, slownessAmplifier, false, false, false));
                    liv.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, slownessDuration, 2, false, false, false));
                    
                    // Mud particles
                    w.spawnParticles(ParticleTypes.FALLING_DUST, 
                        liv.getX(), liv.getY(), liv.getZ(), 
                        3, 0.3, 0.2, 0.3, 0.1);
                }
            }
            
            // Spawn mud/dirt particles in the area
            for (int i = 0; i < 8; i++) {
                double x = start.x + (Math.random() - 0.5) * size;
                double z = start.z + (Math.random() - 0.5) * size;
                w.spawnParticles(ParticleTypes.FALLING_DUST, x, start.y + 0.2, z, 2, 0.2, 0.1, 0.2, 0.05);
            }
        });
        
        player.sendMessage(net.minecraft.text.Text.literal("§7✦ Earth Release: Mud Wave!"), false);
    }
}
