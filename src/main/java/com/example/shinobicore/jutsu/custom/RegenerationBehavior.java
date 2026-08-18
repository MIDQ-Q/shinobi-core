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

public class RegenerationBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        Vec3d pos = player.getPos();

        player.heal(damage * 2f);
        ClanParticleEffects.regeneration(world, pos);
        player.addStatusEffect(new net.minecraft.entity.effect.StatusEffectInstance(
            net.minecraft.entity.effect.StatusEffects.REGENERATION, 100, 1, false, true));
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_CHERRY_LEAVES_HIT, SoundCategory.PLAYERS, 1.0f, 1.2f);
        JutsuLogger.logBehavior(def.id(), "cast at " + pos);
    }
}