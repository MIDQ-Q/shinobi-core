package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.EquipmentSlot;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.ai.goal.ActiveTargetGoal;
import net.minecraft.entity.ai.goal.LookAroundGoal;
import net.minecraft.entity.ai.goal.LookAtEntityGoal;
import net.minecraft.entity.ai.goal.MeleeAttackGoal;
import net.minecraft.entity.ai.goal.WanderAroundGoal;
import net.minecraft.entity.decoration.ArmorStandEntity;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.item.Items;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

/**
 * Water Clone Technique - creates a clone of the player made of water
 * The clone looks like the player and attacks enemies
 */
public class WaterCloneBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        int count = params.has("count") ? params.get("count").getAsInt() : 1;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 300; // 15 seconds
        
        for (int i = 0; i < count; i++) {
            double angle = (i / (double) count) * Math.PI * 2;
            double x = player.getX() + Math.cos(angle) * 2;
            double z = player.getZ() + Math.sin(angle) * 2;
            
            // Create Armor Stand as clone base
            ArmorStandEntity clone = EntityType.ARMOR_STAND.create(world);
            if (clone == null) continue;
            
            clone.setPosition(x, player.getY(), z);
            clone.setCustomName(Text.literal("§bWater Clone"));
            clone.setCustomNameVisible(true);
            clone.setInvisible(false);
            clone.setMarker(false);
            clone.setSmall(false);
            clone.setNoBasePlate(false);
            clone.setShowArms(true);
            
            // Copy player armor
            for (EquipmentSlot slot : EquipmentSlot.values()) {
                if (slot.getType() == EquipmentSlot.Type.ARMOR) {
                    ItemStack stack = player.getEquippedStack(slot);
                    if (!stack.isEmpty()) {
                        clone.setEquippedStack(slot, stack.copy());
                    }
                }
            }
            
            // Give clone a water sword
            clone.setEquippedStack(EquipmentSlot.MAINHAND, new ItemStack(Items.DIAMOND_SWORD));
            
            world.spawnEntity(clone);
            
            // Spawn water particles
            world.spawnParticles(ParticleTypes.WATER_SPLASH, x, player.getY() + 1, z, 20, 0.5, 0.5, 0.5, 0.2);
            world.spawnParticles(ParticleTypes.BUBBLE, x, player.getY() + 0.5, z, 10, 0.3, 0.3, 0.3, 0.1);
            
            final ArmorStandEntity cloneFinal = clone;
            
            // Clone lifetime
            TickScheduler.schedule(world, duration, duration, 1, w -> {
                if (!cloneFinal.isRemoved()) {
                    // Death poof with water
                    w.spawnParticles(ParticleTypes.WATER_SPLASH, cloneFinal.getX(), cloneFinal.getY() + 1, cloneFinal.getZ(), 30, 0.5, 0.5, 0.5, 0.2);
                    w.spawnParticles(ParticleTypes.POOF, cloneFinal.getX(), cloneFinal.getY() + 1, cloneFinal.getZ(), 15, 0.5, 0.5, 0.5, 0.1);
                    cloneFinal.discard();
                }
            });
            
            // Clone AI - attack nearest enemy
            TickScheduler.schedule(world, 2, 2, duration - 10, w -> {
                if (cloneFinal.isRemoved()) return;
                
                LivingEntity target = findNearestEnemy(w, cloneFinal.getPos(), 12, player);
                if (target != null) {
                    // Move towards target
                    Vec3d direction = target.getPos().subtract(cloneFinal.getPos()).normalize();
                    cloneFinal.setVelocity(direction.multiply(0.3));
                    cloneFinal.velocityModified = true;
                    cloneFinal.lookAt(target, 90, 90);
                    
                    // Attack if close
                    double dist = cloneFinal.getPos().distanceTo(target.getPos());
                    if (dist < 2.5) {
                        target.damage(player.getDamageSources().magic(), damage * 0.4f);
                        // Knockback
                        Vec3d kb = target.getPos().subtract(cloneFinal.getPos()).normalize().multiply(0.4);
                        target.addVelocity(kb.x, 0.2, kb.z);
                        target.velocityModified = true;
                        // Hit particles
                        w.spawnParticles(ParticleTypes.WATER_SPLASH, target.getX(), target.getY() + 1, target.getZ(), 8, 0.3, 0.3, 0.3, 0.1);
                    }
                }
            });
        }
        
        player.sendMessage(Text.literal("§b✦ Water Clone Jutsu! Clone created."), false);
    }
    
    private LivingEntity findNearestEnemy(ServerWorld world, Vec3d from, float range, PlayerEntity caster) {
        LivingEntity best = null;
        double bestDist = Double.MAX_VALUE;
        
        for (Entity e : world.getOtherEntities(caster, new net.minecraft.util.math.Box(from, from).expand(range))) {
            if (e instanceof LivingEntity liv && !liv.equals(caster) && !(e instanceof ArmorStandEntity)) {
                double dist = liv.getPos().distanceTo(from);
                if (dist < bestDist) {
                    bestDist = dist;
                    best = liv;
                }
            }
        }
        
        return best;
    }
}
