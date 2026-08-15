package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.RasenganHandEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;

public class RasenganBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;

        // Удаляем существующий расенган если есть
        for (Entity e : world.getOtherEntities(player, player.getBoundingBox().expand(5))) {
            if (e instanceof RasenganHandEntity rhe) {
                rhe.discard();
            }
        }

        // Создаём 3D сферу в руке
        RasenganHandEntity handEntity = new RasenganHandEntity(world, player, damage);
        world.spawnEntity(handEntity);
        player.sendMessage(Text.literal("\u00a7b\u2726 Rasengan ready! Attack to strike!"), false);

        JutsuLogger.logBehavior("rasengan",
            String.format("HAND SPHERE: player=%s, damage=%.1f",
            player.getName().getString(), damage));
    }
}