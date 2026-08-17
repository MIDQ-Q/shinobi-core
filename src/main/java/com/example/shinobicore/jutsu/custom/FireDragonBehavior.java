package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.entity.DragonEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Vec3d;

public class FireDragonBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 4f;
        Vec3d look = player.getRotationVector();

        // S5-04: Segmented fire dragon
        DragonEntity dragon = new DragonEntity(
            world, player, look.multiply(speed), "fire", damage, radius, 8
        );
        world.spawnEntity(dragon);

        world.playSound(null, player.getBlockPos(),
            SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 1.5f, 1.2f);

        JutsuLogger.logBehavior("fire_dragon", "speed=" + speed + " radius=" + radius);
    }
}