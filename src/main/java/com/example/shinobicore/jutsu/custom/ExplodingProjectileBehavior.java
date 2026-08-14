package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class ExplodingProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.8f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
        
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        
        NinjaProjectileEntity proj = new NinjaProjectileEntity(
            world, player, look.multiply(speed), damage, radius, "fire", "default", 100
        );
        proj.setPosition(eye.x, eye.y - 0.2, eye.z);
        proj.setHasGravity(true);
        world.spawnEntity(proj);
    }
}