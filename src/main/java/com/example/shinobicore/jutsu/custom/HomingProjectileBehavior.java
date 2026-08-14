package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.projectile.FireballEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class HomingProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        int count = params.has("count") ? params.get("count").getAsInt() : 12;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        for (int i = 0; i < count; i++) {
            final int idx = i;
            TickScheduler.schedule(world, i * 3, 3, 1, w -> {
                FireballEntity fb = new FireballEntity(w, player, look.x, look.y, look.z, 0);
                fb.setPosition(eye.x, eye.y, eye.z);
                fb.setVelocity(look.x * speed, look.y * speed, look.z * speed, 0.1f, 0.1f);
                w.spawnEntity(fb);
                TickScheduler.schedule(w, 1, 2, 30, world2 -> {
                    if (fb.isRemoved()) return;
                    LivingEntity target = findClosest(world2, fb.getPos(), 16, player);
                    if (target != null) {
                        Vec3d to = target.getPos().add(0, target.getHeight() / 2, 0).subtract(fb.getPos()).normalize();
                        Vec3d vel = fb.getVelocity();
                        Vec3d newVel = vel.multiply(0.9).add(to.multiply(0.3));
                        fb.setVelocity(newVel.x, newVel.y, newVel.z, 0.1f, 0.1f);
                    }
                });
            });
        }
        JutsuLogger.logBehavior("homing_projectile", "count=" + count);
    }
    private LivingEntity findClosest(ServerWorld world, Vec3d from, float range, ServerPlayerEntity caster) {
        LivingEntity best = null;
        double bestDist = Double.MAX_VALUE;
        for (Entity e : world.getOtherEntities(caster, new net.minecraft.util.math.Box(from, from).expand(range))) {
            if (e instanceof LivingEntity liv && !liv.equals(caster)) {
                double d = liv.getPos().distanceTo(from);
                if (d < bestDist) { bestDist = d; best = liv; }
            }
        }
        return best;
    }
}