package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.VoxelProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

/**
 * Поведение для Bakuton - серия из 4 взрывов с интервалом 1 секунду
 */
public class BakutonBehavior implements JutsuBehavior {
    
    private static final int EXPLOSION_COUNT = 4;
    private static final int EXPLOSION_INTERVAL_TICKS = 20; // 1 секунда
    private static final float EXPLOSION_RADIUS = 3.0f;
    private static final float EXPLOSION_DAMAGE = 8.0f;
    
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.8f;
        Vec3d look = player.getRotationVector();
        
        // Создаем снаряд с кастомным тикером для серии взрывов
        VoxelProjectileEntity proj = new VoxelProjectileEntity(
            world, player, look.multiply(speed), "fireball", 0xFFFF6600, 0.5f, damage, false, true, 3.0f
        );
        world.spawnEntity(proj);
        
        // Добавляем логику серии взрывов через NBT или специальный флаг
        proj.setCustomData("bakuton_explosions", EXPLOSION_COUNT);
        proj.setCustomData("bakuton_interval", EXPLOSION_INTERVAL_TICKS);
    }
}