package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Box;

public class MeleeBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        float range = params.has("range") ? params.get("range").getAsFloat() : 2.0f;
        float width = params.has("width") ? params.get("width").getAsFloat() : 1.5f;
        
        Box box = player.getBoundingBox().expand(width, 0.5, width);
        for (Entity entity : player.getWorld().getOtherEntities(player, box)) {
            if (entity instanceof LivingEntity living && !living.equals(player)) {
                double dist = player.squaredDistanceTo(entity);
                if (dist <= range * range) {
                    living.damage(player.getDamageSources().magic(), damage);
                }
            }
        }
    }
}