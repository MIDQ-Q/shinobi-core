package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

public class ShadowStepBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float teleportDistance = params.has("distance") ? params.get("distance").getAsFloat() : 12f;
        int smokeParticles = params.has("smokeCount") ? params.get("smokeCount").getAsInt() : 40;
        
        Vec3d oldPos = player.getPos();
        Vec3d look = player.getRotationVector().normalize();
        Vec3d newPos = oldPos.add(look.multiply(teleportDistance));
        
        // Проверка и коррекция позиции (чтобы не телепортироваться в блоки)
        BlockPos targetBlock = BlockPos.ofFloored(newPos.x, newPos.y, newPos.z);
        if (!world.getBlockState(targetBlock).isAir() || !world.getBlockState(BlockPos.ofFloored(newPos.x, newPos.y + 1, newPos.z)).isAir()) {
            // Если целевая позиция занята, пробуем найти свободное место выше
            for (int y = 0; y < 3; y++) {
                BlockPos checkPos = BlockPos.ofFloored(newPos.x, newPos.y + y, newPos.z);
                BlockPos abovePos = BlockPos.ofFloored(newPos.x, newPos.y + y + 1, newPos.z);
                if (world.getBlockState(checkPos).isAir() && world.getBlockState(abovePos).isAir()) {
                    newPos = new Vec3d(newPos.x, newPos.y + y, newPos.z);
                    break;
                }
            }
        }
        
        // Частицы дыма на старой позиции
        for (int i = 0; i < smokeParticles; i++) {
            world.spawnParticles(ParticleTypes.LARGE_SMOKE,
                    oldPos.x + (Math.random() - 0.5) * 1.5, 
                    oldPos.y + Math.random() * 1.8, 
                    oldPos.z + (Math.random() - 0.5) * 1.5,
                    1, 0.1, 0.1, 0.1, 0.05);
            world.spawnParticles(ParticleTypes.SMOKE,
                    oldPos.x + (Math.random() - 0.5) * 1.2, 
                    oldPos.y + Math.random() * 1.5, 
                    oldPos.z + (Math.random() - 0.5) * 1.2,
                    1, 0.08, 0.08, 0.08, 0.03);
        }
        
        // Звук телепортации
        world.playSound(null, BlockPos.ofFloored(oldPos), SoundEvents.ENTITY_ENDERMAN_TELEPORT, SoundCategory.PLAYERS, 0.8f, 0.9f);
        
        // Телепортация игрока
        player.teleport(newPos.x, newPos.y, newPos.z);
        
        // Частицы дыма на новой позиции
        for (int i = 0; i < smokeParticles / 2; i++) {
            world.spawnParticles(ParticleTypes.LARGE_SMOKE,
                    newPos.x + (Math.random() - 0.5) * 1.5, 
                    newPos.y + Math.random() * 1.8, 
                    newPos.z + (Math.random() - 0.5) * 1.5,
                    1, 0.1, 0.1, 0.1, 0.05);
        }
        
        // Кратковременный бафф скорости после телепортации
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.SPEED, 30, 1, false, false));
        
        JutsuLogger.logBehavior("shadow_step", "player=" + player.getName().getString() + " dist=" + teleportDistance);
    }
}
