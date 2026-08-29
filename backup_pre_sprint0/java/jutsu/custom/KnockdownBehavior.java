package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class KnockdownBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 8f;
        int stunDuration = params.has("stunDuration") ? params.get("stunDuration").getAsInt() : 40;
        float knockback = params.has("knockback") ? params.get("knockback").getAsFloat() : 1.5f;
        Vec3d center = player.getPos();
        int count = 0;
        for (Entity e : world.getOtherEntities(player,
                new net.minecraft.util.math.Box(center, center).expand(radius))) {
            if (e instanceof LivingEntity liv && !liv.equals(player)) {
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, stunDuration, 255, false, false));
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, stunDuration, 255, false, false));
                Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(knockback);
                liv.addVelocity(kb.x, 0.3, kb.z);
                liv.velocityModified = true;
                if (damage > 0) liv.damage(player.getDamageSources().magic(), damage);
                count++;
            }
        }
        for (int i = 0; i < 50; i++) {
            double a = (i / 50.0) * Math.PI * 2;
            double r = radius * (i % 3 == 0 ? 1.0 : 0.7);
            world.spawnParticles(ParticleTypes.EXPLOSION,
                    center.x + Math.cos(a) * r, center.y, center.z + Math.sin(a) * r,
                    1, 0, 0.1, 0, 0.05);
        }
        JutsuLogger.logBehavior("knockdown", "radius=" + radius + " targets=" + count);
    }
}