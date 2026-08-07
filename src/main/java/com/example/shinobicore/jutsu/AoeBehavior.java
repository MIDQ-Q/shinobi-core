package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;

public class AoeBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 3.0f;
        
        for (Entity entity : player.getWorld().getOtherEntities(player, player.getBoundingBox().expand(radius))) {
            if (entity instanceof LivingEntity living && !living.equals(player)) {
                living.damage(player.getDamageSources().magic(), damage);
            }
        }
    }
}