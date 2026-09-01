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

public class RootBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 8f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 5f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 80;
        boolean fromTarget = params.has("fromTarget") && params.get("fromTarget").getAsBoolean();
        Vec3d center;
        if (fromTarget) {
            Vec3d eye = player.getEyePos();
            Vec3d end = eye.add(player.getRotationVector().multiply(range));
            var hit = world.raycast(new net.minecraft.world.RaycastContext(eye, end,
                    net.minecraft.world.RaycastContext.ShapeType.OUTLINE,
                    net.minecraft.world.RaycastContext.FluidHandling.NONE, player));
            center = hit.getPos();
        } else {
            center = player.getPos().add(player.getRotationVector().multiply(range));
        }
        int count = 0;
        for (Entity e : world.getOtherEntities(player,
                new net.minecraft.util.math.Box(center, center).expand(radius))) {
            if (e instanceof LivingEntity liv && !liv.equals(player)) {
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, duration, 255, false, false));
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, duration, 255, false, false));
                liv.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, duration, 1, false, false));
                if (damage > 0) liv.damage(player.getDamageSources().magic(), damage);
                count++;
            }
        }
        for (int i = 0; i < 40; i++) {
            double a = (i / 40.0) * Math.PI * 2;
            world.spawnParticles(ParticleTypes.SCULK_SOUL,
                    center.x + Math.cos(a) * radius * 0.8,
                    center.y + 0.2,
                    center.z + Math.sin(a) * radius * 0.8,
                    2, 0.1, 0.3, 0.1, 0.05);
        }
        JutsuLogger.logBehavior("root", "centered targets=" + count + " radius=" + radius);
    }
}