package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.behavior.JutsuBehavior;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.util.ColorHelper;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.JsonHelper;
import net.minecraft.util.math.Vec3d;

/**
 * Custom behavior: large fire dragon projectile with strong burn.
 * Registered in BehaviorRegistry under id "fire_dragon".
 * HLD: Section 2.2
 */
public class FireDragonBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
        float speed = JsonHelper.getFloat(params, "speed", 2.5f);
        float radius = JsonHelper.getFloat(params, "radius", 3.0f);
        int burn = JsonHelper.getInt(params, "burn_seconds", 6);
        int lifetime = JsonHelper.getInt(params, "lifetime", 100);
        int color = ColorHelper.parse(JsonHelper.getString(def.visuals(), "color", "#FF3300"));

        Vec3d look = player.getRotationVector();
        Vec3d spawn = player.getEyePos().add(look.multiply(2.0));

        NinjaProjectileEntity dragon = new NinjaProjectileEntity(
            player.getWorld(), player, damage, radius, "flame",
            color, false, burn, lifetime
        );
        dragon.setVelocity(look.multiply(speed));
        dragon.setPosition(spawn.x, spawn.y, spawn.z);
        player.getWorld().spawnEntity(dragon);
    }
}