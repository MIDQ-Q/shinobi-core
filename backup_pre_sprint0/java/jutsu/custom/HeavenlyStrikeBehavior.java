package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class HeavenlyStrikeBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float radius = params.has("radius") ? params.has("radius") ? params.get("radius").getAsFloat() : 4f : 4f;
        float knockdown = params.has("knockdown") ? params.get("knockdown").getAsFloat() : 1.2f;
        // Jump FORWARD + UP
        Vec3d look = player.getRotationVector();
        player.addVelocity(look.x * 0.6, 0.9, look.z * 0.6);
        player.velocityModified = true;
        TickScheduler.schedule(world, 14, 14, 1, w -> {
            Vec3d center = player.getPos();
            for (Entity e : w.getOtherEntities(player, new Box(center, center).expand(radius))) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    liv.damage(player.getDamageSources().magic(), damage);
                    Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(knockdown);
                    liv.addVelocity(kb.x, -0.3, kb.z);
                    liv.velocityModified = true;
                }
            }
            for (int i = 0; i < 50; i++) {
                double a = (i / 50.0) * Math.PI * 2;
                w.spawnParticles(ParticleTypes.CRIT,
                    center.x + Math.cos(a) * radius, center.y, center.z + Math.sin(a) * radius,
                    2, 0, 0.15, 0, 0.05);
            }
            w.spawnParticles(ParticleTypes.EXPLOSION, center.x, center.y, center.z, 3, 0.5, 0.2, 0.5, 0.02);
        });
        JutsuLogger.logBehavior("heavenly_strike", "radius=" + radius);
    }
}