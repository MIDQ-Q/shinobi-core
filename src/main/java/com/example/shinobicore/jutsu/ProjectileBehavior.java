package com.example.shinobicore.jutsu;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class ProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
        String particle = params.has("particle") ? params.get("particle").getAsString() : "flame";
        if ("none".equals(particle)) particle = "wind";
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 80;
        boolean gravity = params.has("gravity") && params.get("gravity").getAsBoolean();
        int pierce = params.has("pierce") ? params.get("pierce").getAsInt() : 0;
        int count = params.has("count") ? params.get("count").getAsInt() : 1;
        float spread = params.has("spread") ? params.get("spread").getAsFloat() : 0f;

        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();

        for (int i = 0; i < count; i++) {
            Vec3d dir = look;
            if (count > 1 && spread > 0) {
                double angle = (i - (count - 1) / 2.0) * spread;
                double rad = Math.toRadians(angle);
                double cos = Math.cos(rad), sin = Math.sin(rad);
                dir = new Vec3d(dir.x * cos - dir.z * sin, dir.y, dir.x * sin + dir.z * cos).normalize();
            }
            
            NinjaProjectileEntity proj = new NinjaProjectileEntity(
                world, player, dir.multiply(speed), damage, radius, particle, "default", lifetime
            );
            proj.setPosition(eye.x, eye.y - 0.2, eye.z);
            proj.setHasGravity(gravity);
            proj.setPierceCount(pierce);
            world.spawnEntity(proj);
        }
    }
}