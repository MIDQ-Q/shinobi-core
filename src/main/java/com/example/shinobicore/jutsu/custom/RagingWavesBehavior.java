package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.block.Blocks;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class RagingWavesBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        int width = params.has("width") ? params.get("width").getAsInt() : 3;
        int height = params.has("height") ? params.get("height").getAsInt() : 3;
        int travelDistance = params.has("travelDistance") ? params.get("travelDistance").getAsInt() : 3;
        
        Vec3d start = player.getPos().add(player.getRotationVector().multiply(2));
        Vec3d direction = player.getRotationVector().normalize();
        
        // Создаем волну из блоков воды 3x3x1 которая движется вперед
        for (int step = 0; step < travelDistance; step++) {
            final int currentStep = step;
            final Vec3d waveStart = start.add(direction.multiply(currentStep * 2));
            
            // Появление волны на шаге
            TickScheduler.schedule(world, currentStep * 10, 0, 1, w -> {
                createWaveStep(w, waveStart, direction, width, height, player, damage);
            });
            
            // Удаление волны через 5 секунд после появления
            TickScheduler.schedule(world, currentStep * 10 + 100, 0, 1, w -> {
                removeWaveStep(w, waveStart, width, height);
            });
        }
        
        JutsuLogger.logBehavior("raging_waves", "travelDistance=" + travelDistance);
    }
    
    private void createWaveStep(ServerWorld world, Vec3d center, Vec3d direction, 
                                int width, int height, ServerPlayerEntity caster, float damage) {
        BlockPos pos = BlockPos.ofFloored(center);
        List<BlockPos> placed = new ArrayList<>();
        
        // Создаем блоки воды 3x3x1
        for (int dx = -width/2; dx <= width/2; dx++) {
            for (int dy = 0; dy < height; dy++) {
                BlockPos blockPos = pos.add(dx, dy, 0);
                if (world.getBlockState(blockPos).isAir()) {
                    world.setBlockState(blockPos, Blocks.WATER.getDefaultState(), 3);
                    placed.add(blockPos);
                }
            }
        }
        
        // Отталкиваем противников на 3 блока
        Box area = new Box(pos.add(-width/2, 0, -1), pos.add(width/2, height, 1));
        for (Entity entity : world.getOtherEntities(caster, area)) {
            if (entity instanceof LivingEntity living && !living.equals(caster)) {
                living.damage(caster.getDamageSources().magic(), damage);
                Vec3d knockback = direction.multiply(3.0);
                living.addVelocity(knockback.x, 0.5, knockback.z);
                living.velocityModified = true;
            }
        }
        
        // Частицы воды
        world.spawnParticles(net.minecraft.particle.ParticleTypes.SPLASH,
                center.x, center.y + 1, center.z,
                20, width/2.0, height/2.0, 0.5, 0.1);
    }
    
    private void removeWaveStep(ServerWorld world, Vec3d center, int width, int height) {
        BlockPos pos = BlockPos.ofFloored(center);
        for (int dx = -width/2; dx <= width/2; dx++) {
            for (int dy = 0; dy < height; dy++) {
                BlockPos blockPos = pos.add(dx, dy, 0);
                if (world.getBlockState(blockPos).getBlock() == Blocks.WATER) {
                    world.removeBlock(blockPos, false);
                }
            }
        }
    }
}
