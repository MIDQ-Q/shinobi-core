package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.effects.ClanParticleEffects;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Vec3d;

public class WoodDragonBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        Vec3d pos = player.getPos();

        float radius = 6f;
        ClanParticleEffects.woodGrowth(world, pos, radius);
        ClanParticleEffects.aoeDamage(world, player, pos, radius, damage);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BAMBOO_BREAK, SoundCategory.PLAYERS, 1.5f, 0.6f);
        JutsuLogger.logBehavior(def.id(), "cast at " + pos);
    }
}