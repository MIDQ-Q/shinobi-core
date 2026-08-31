package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.projectile.thrown.SnowballEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class BoomerangBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        SnowballEntity sb = new SnowballEntity(world, player);
        sb.setPosition(eye.x, eye.y, eye.z);
        sb.setVelocity(look.x * speed, look.y * speed, look.z * speed, 0.1f, 0.1f);
        world.spawnEntity(sb);
        TickScheduler.schedule(world, 30, 2, 30, w -> {
            if (sb.isRemoved()) return;
            Vec3d to = player.getPos().add(0, 1, 0).subtract(sb.getPos()).normalize();
            Vec3d vel = sb.getVelocity();
            Vec3d newVel = vel.multiply(0.85).add(to.multiply(0.35));
            sb.setVelocity(newVel.x, newVel.y, newVel.z, 0.1f, 0.1f);
            w.spawnParticles(ParticleTypes.CLOUD, sb.getX(), sb.getY(), sb.getZ(), 2, 0.1, 0.1, 0.1, 0.02);
            if (sb.distanceTo(player) < 1.5) sb.discard();
        });
        JutsuLogger.logBehavior("boomerang", "speed=" + speed);
    }
}