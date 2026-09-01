package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.projectile.FireballEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class ExplodingProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.8f;
        int explosionPower = params.has("radius") ? (int) params.get("radius").getAsFloat() : 4;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        FireballEntity fb = new FireballEntity(world, player, look.x, look.y, look.z, explosionPower);
        fb.setPosition(eye.x, eye.y, eye.z);
        fb.setVelocity(look.x * speed, look.y * speed, look.z * speed, 0.1f, 0.1f);
        world.spawnEntity(fb);
        JutsuLogger.logBehavior("exploding_projectile", "power=" + explosionPower);
    }
}