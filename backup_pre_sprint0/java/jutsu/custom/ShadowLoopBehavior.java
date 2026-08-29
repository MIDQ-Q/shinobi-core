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

public class ShadowLoopBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        Vec3d pos = player.getPos();

        java.util.List<LivingEntity> targets = new java.util.ArrayList<>();
        for (var e : world.getOtherEntities(player, new net.minecraft.util.math.Box(pos.subtract(5, 3, 5), pos.add(5, 3, 5)))) {
            if (e instanceof LivingEntity liv) {
                targets.add(liv);
                ClanParticleEffects.applySlowness(liv, 80, 3);
            }
        }
        ClanParticleEffects.shadowTrap(world, pos);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_SOUL_SAND_PLACE, SoundCategory.PLAYERS, 1.0f, 0.6f);
        JutsuLogger.logBehavior(def.id(), "cast at " + pos);
    }
}