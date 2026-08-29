package com.example.shinobicore.jutsu.behavior;
import com.example.shinobicore.progression.JutsuCastNotifier;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.util.ColorHelper;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.JsonHelper;
import net.minecraft.util.math.Vec3d;

/**
 * Spawns generic JSON-driven projectiles.
 * HLD: Section 2.2, 2.3
 */
public class ProjectileBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
        JutsuCastNotifier.fire(player, "projectile", "ninjutsu");

        float speed = JsonHelper.getFloat(params, "speed", 1.5f);
        float radius = JsonHelper.getFloat(params, "radius", 1.0f);
        boolean gravity = JsonHelper.getBoolean(params, "gravity", false);
        String particle = JsonHelper.getString(params, "particle", "flame");
        int count = JsonHelper.getInt(params, "count", 1);
        float spread = JsonHelper.getFloat(params, "spread", 0.0f);
        int lifetime = JsonHelper.getInt(params, "lifetime", 100);
        int burn = JsonHelper.getInt(params, "burn_seconds", 0);
        int color = ColorHelper.parse(JsonHelper.getString(def.visuals(), "color", "#FFFFFF"));

        Vec3d look = player.getRotationVector();
        Vec3d spawn = player.getEyePos().add(look.multiply(1.5));

        for (int i = 0; i < count; i++) {
            NinjaProjectileEntity projectile = new NinjaProjectileEntity(
                player.getWorld(), player, damage, radius, particle,
                color, gravity, burn, lifetime
            );

            Vec3d vel = look.multiply(speed);
            if (count > 1 && spread > 0.0f) {
                double ox = (player.getRandom().nextFloat() - 0.5f) * spread;
                double oy = (player.getRandom().nextFloat() - 0.5f) * spread;
                double oz = (player.getRandom().nextFloat() - 0.5f) * spread;
                vel = vel.add(ox, oy, oz);
            }

            projectile.setVelocity(vel);
            projectile.setPosition(spawn.x, spawn.y, spawn.z);
            player.getWorld().spawnEntity(projectile);
        }
    }
}