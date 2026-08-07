package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class DashBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        float distance = params.has("distance") ? params.get("distance").getAsFloat() : 5.0f;
        
        Vec3d look = player.getRotationVector().multiply(distance);
        player.addVelocity(look.x, 0.1, look.z);
        player.velocityModified = true;
    }
}