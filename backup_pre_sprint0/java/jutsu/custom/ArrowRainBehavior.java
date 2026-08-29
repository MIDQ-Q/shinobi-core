package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.projectile.ArrowEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class ArrowRainBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        int count = params.has("count") ? params.get("count").getAsInt() : 12;
        float area = params.has("area") ? params.get("area").getAsFloat() : 6f;
        double perArrow = params.has("arrowDamage") ? params.get("arrowDamage").getAsDouble() : 4.0;
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(8)).add(0, 25, 0);
        
        for (int i = 0; i < count; i++) {
            ArrowEntity arrow = new ArrowEntity(world, player);
            double x = center.x + (Math.random() - 0.5) * area * 2;
            double z = center.z + (Math.random() - 0.5) * area * 2;
            arrow.setPosition(x, center.y, z);
            arrow.setVelocity((Math.random() - 0.5) * 0.4, -2.0, (Math.random() - 0.5) * 0.4);
            arrow.setDamage(perArrow);
            
            // Track arrow position for water block spawn
            final double arrowX = x;
            final double arrowZ = z;
            
            // Spawn water block at impact after delay
            int delay = (int)(center.y / 2.0); // Approximate fall time
            net.minecraft.util.TickScheduler.getInstance().scheduleTick(world, delay + 5, w -> {
                // Spawn water particles at impact
                w.spawnParticles(ParticleTypes.WATER_SPLASH, arrowX, player.getY(), arrowZ, 15, 0.5, 0.3, 0.5, 0.1);
                // Could add temporary water block here if needed
            });
            
            world.spawnEntity(arrow);
        }
        JutsuLogger.logBehavior("arrow_rain", "count=" + count + " area=" + area);
    }
}