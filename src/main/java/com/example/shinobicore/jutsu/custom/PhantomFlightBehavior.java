package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.entity.mob.PhantomEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class PhantomFlightBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 400;
        PhantomEntity phantom = EntityType.PHANTOM.create(world);
        if (phantom == null) return;
        Vec3d spawn = player.getPos().add(0, 3, 0);
        phantom.setPosition(spawn.x, spawn.y, spawn.z);
        phantom.setAiDisabled(false);
        world.spawnEntity(phantom);
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.LEVITATION, duration, 1, false, false));
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOW_FALLING, duration + 60, 0, false, false));
        JutsuLogger.logBehavior("phantom_flight", "dur=" + duration);
    }
}