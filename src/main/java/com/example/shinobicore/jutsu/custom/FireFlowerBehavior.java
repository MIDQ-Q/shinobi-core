package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.VoxelProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

/**
 * Fire Release: Great Flame Flower - Shoots a fireball that explodes on impact
 * with AoE damage, knockback and levitation effect.
 */
public class FireFlowerBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float speed = 2.0f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
        float distance = params.has("distance") ? params.get("distance").getAsFloat() : 8f;
        float explosionRadius = radius * 0.6f;
        
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        
        // Create fireball projectile that explodes on hit
        VoxelProjectileEntity proj = new VoxelProjectileEntity(
            world, player, look.multiply(speed), "fireball", 0xFFFF5500, radius * 0.4f, damage, false, true, explosionRadius
        );
        world.spawnEntity(proj);
    }
}
