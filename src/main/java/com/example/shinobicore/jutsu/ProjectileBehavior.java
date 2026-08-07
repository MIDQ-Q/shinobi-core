package com.example.shinobicore.jutsu;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class ProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
        String particle = params.has("particle") ? params.get("particle").getAsString() : "flame";
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;

        Vec3d look = player.getRotationVector().multiply(speed);
        NinjaProjectileEntity projectile = new NinjaProjectileEntity(
            player.getWorld(), player, look, damage, radius, particle, lifetime
        );
        player.getWorld().spawnEntity(projectile);
    }
}