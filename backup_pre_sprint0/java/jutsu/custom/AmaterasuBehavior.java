package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.VoxelProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

/**
 * Amaterasu - Black flames that burn for 60 seconds with triple damage.
 * Requires Sharingan to cast.
 */
public class AmaterasuBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        // Require Sharingan
        if (data.getActiveDojutsu() == null || !data.getActiveDojutsu().equals("sharingan")) {
            player.sendMessage(net.minecraft.text.Text.literal("§cRequires Sharingan!"), false);
            return;
        }
        
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.5f;
        int burnDuration = params.has("burnDuration") ? params.get("burnDuration").getAsInt() : 1200; // 60 seconds = 1200 ticks
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 120; // 6 seconds flight time
        
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        
        // Triple damage for Amaterasu
        float amaterasuDamage = damage * 3.0f;
        
        // Create black fireball projectile with explosion on hit and Amaterasu effect
        VoxelProjectileEntity proj = new VoxelProjectileEntity(
            world, player, look.multiply(speed), "amaterasu", 0xFF000000, radius, amaterasuDamage, false,
            true, 2.0f, "amaterasu"
        );
        world.spawnEntity(proj);
    }
    
    /**
     * Applies Amaterasu burning effect to an entity - black flames for 60 seconds with triple damage
     */
    public static void applyAmaterasuBurn(LivingEntity target, int durationTicks) {
        // Apply regular fire for visual effect
        target.setOnFireFor(durationTicks / 20);
        
        // Add weakness to simulate the debilitating effect of Amaterasu
        target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, durationTicks, 1, false, false));
    }
}