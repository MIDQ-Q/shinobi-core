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

public class ZoneBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 10f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 5f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 160;
        float tickDamage = params.has("tickDamage") ? params.get("tickDamage").getAsFloat() : 2f;
        int tickInterval = params.has("tickInterval") ? params.get("tickInterval").getAsInt() : 20;
        boolean burn = params.has("burn") && params.get("burn").getAsBoolean();
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        Box box = new Box(center, center).expand(radius);
        int ticks = Math.max(1, duration / tickInterval);
        TickScheduler.schedule(world, 1, tickInterval, ticks, w -> {
            for (Entity e : w.getOtherEntities(player, box)) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    liv.damage(player.getDamageSources().magic(), tickDamage);
                    if (burn) liv.setOnFireFor(3);
                }
            }
            for (int i = 0; i < 40; i++) {
                double a = Math.random() * Math.PI * 2;
                double r = Math.random() * radius;
                w.spawnParticles(ParticleTypes.FLAME,
                    center.x + Math.cos(a) * r, center.y + 0.1 + Math.random() * 0.8, center.z + Math.sin(a) * r,
                    1, 0, 0.06, 0, 0.03);
            }
            for (int i = 0; i < 15; i++) {
                double a = Math.random() * Math.PI * 2;
                double r = Math.random() * radius;
                w.spawnParticles(ParticleTypes.LARGE_SMOKE,
                    center.x + Math.cos(a) * r, center.y + 0.3, center.z + Math.sin(a) * r,
                    1, 0, 0.04, 0, 0.01);
            }
        });
        JutsuLogger.logBehavior("zone", "radius=" + radius + " ticks=" + ticks);
    }
}