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
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

/**
 * Rock Pillar Technique - stalactite-like pillars erupt from ground
 * Uses pointed dripstone appearance for stalactite effect
 */
public class RockPillarBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float range = params.has("range") ? params.get("range").getAsFloat() : 10f;
        int pillarCount = params.has("pillarCount") ? params.get("pillarCount").getAsInt() : 5;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
        float knockback = params.has("knockback") ? params.get("knockback").getAsFloat() : 2.5f;
        
        Vec3d look = player.getRotationVector();
        Vec3d center = player.getPos().add(look.multiply(range));
        
        // Create multiple rock pillars in area
        for (int i = 0; i < pillarCount; i++) {
            double angle = (i / (float)pillarCount) * Math.PI * 2;
            double r = Math.random() * radius * 0.8;
            double x = center.x + Math.cos(angle) * r;
            double z = center.z + Math.sin(angle) * r;
            
            BlockPos pillarPos = BlockPos.ofFloored(x, center.y - 1, z);
            
            // Check if position is valid (air above ground)
            if (!world.isAir(pillarPos) || world.isAir(pillarPos.up())) {
                // Create stalactite pillar (pointed dripstone pointing up)
                world.setBlockState(pillarPos, Blocks.POINTED_DRIPSTONE.getDefaultState()
                    .with(net.minecraft.block.PointedDripstoneBlock.TIP, false)
                    .with(net.minecraft.block.PointedDripstoneBlock.VERTICAL_DIRECTION, net.minecraft.enums.Direction.UP));
                
                // Add stone block below for stability appearance
                if (world.isAir(pillarPos.down())) {
                    world.setBlockState(pillarPos.down(), Blocks.STONE.getDefaultState());
                }
                
                final BlockPos removePos = pillarPos.toImmutable();
                final BlockPos basePos = pillarPos.down().toImmutable();
                
                // Remove pillar after delay
                TickScheduler.schedule(world, 60, 1, 1, w -> {
                    if (w.getBlockState(removePos).getBlock() == Blocks.POINTED_DRIPSTONE) {
                        w.setBlockState(removePos, Blocks.AIR.getDefaultState());
                        if (w.getBlockState(basePos).getBlock() == Blocks.STONE) {
                            w.setBlockState(basePos, Blocks.AIR.getDefaultState());
                        }
                    }
                });
                
                // Eruption particles and sound
                world.spawnParticles(ParticleTypes.BLOCK, x, center.y, z, 20, 0.3, 0.5, 0.3, 0.1);
                world.playSound(null, pillarPos, SoundEvents.BLOCK_STONE_PLACE, SoundCategory.BLOCKS, 1.2f, 0.8f);
            }
        }
        
        // Damage and knockback enemies in area
        Box effectBox = new Box(center.add(-radius, 0, -radius), center.add(radius, 3, radius));
        
        for (Entity e : world.getOtherEntities(player, effectBox)) {
            if (e instanceof LivingEntity liv && !liv.equals(player)) {
                liv.damage(player.getDamageSources().magic(), damage);
                
                // Knockback upward and outward
                Vec3d kb = liv.getPos().subtract(center).normalize().multiply(knockback);
                liv.addVelocity(kb.x, 0.8, kb.z);
                liv.velocityModified = true;
                
                // Brief levitation for dramatic effect
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.LEVITATION, 20, 0, false, false, false));
                
                // Impact particles
                world.spawnParticles(ParticleTypes.BLOCK, liv.getX(), liv.getY(), liv.getZ(), 
                    8, 0.3, 0.3, 0.3, 0.1);
            }
        }
        
        player.sendMessage(net.minecraft.text.Text.literal("§7✦ Earth Release: Rock Pillar!"), false);
    }
}
