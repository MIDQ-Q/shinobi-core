package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
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
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
        
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        
        for (int i = 0; i < count; i++) {
            Vec3d dir = look.add((Math.random() - 0.5) * 0.5, (Math.random() - 0.5) * 0.5, (Math.random() - 0.5) * 0.5).normalize();
            NinjaProjectileEntity proj = new NinjaProjectileEntity(
                world, player, dir.multiply(speed), damage, radius, "fire", "default", 80
            );
            proj.setPosition(eye.x, eye.y - 0.2, eye.z);
            proj.setPierceCount(1);
            world.spawnEntity(proj);
        }
    }
}