package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class PullBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 12f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 6f;
        float pullStrength = params.has("pullStrength") ? params.get("pullStrength").getAsFloat() : 0.35f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 60;
        Vec3d center = player.getPos().add(player.getRotationVector().multiply(range));
        Box box = new Box(center, center).expand(radius);
        int ticks = Math.max(1, duration / 5);
        TickScheduler.schedule(world, 1, 5, ticks, w -> {
            for (Entity e : w.getOtherEntities(player, box)) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    Vec3d to = center.subtract(liv.getPos());
                    double dist = to.length();
                    if (dist > 0.5) {
                        Vec3d pull = to.normalize().multiply(pullStrength);
                        liv.setVelocity(pull.x, liv.getVelocity().y * 0.5, pull.z);
                        liv.velocityModified = true;
                    }
                    liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 20, 1, false, false));
                    if (damage > 0) liv.damage(player.getDamageSources().magic(), damage * 0.2f);
                }
            }
            for (int i = 0; i < 20; i++) {
                double a = (i / 20.0) * Math.PI * 2;
                w.spawnParticles(ParticleTypes.PORTAL,
                    center.x + Math.cos(a) * radius, center.y + 0.5, center.z + Math.sin(a) * radius,
                    1, -Math.cos(a) * 0.15, 0.05, -Math.sin(a) * 0.15, 0.03);
            }
        });
        JutsuLogger.logBehavior("pull", "radius=" + radius + " ticks=" + ticks);
    }
}