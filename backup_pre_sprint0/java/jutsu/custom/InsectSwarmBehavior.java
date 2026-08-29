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

public class InsectSwarmBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        Vec3d pos = player.getPos();

        float radius = 4f;
        ClanParticleEffects.insectSwarm(world, pos, radius);
        for (var e : world.getOtherEntities(player, new net.minecraft.util.math.Box(pos.subtract(radius, radius, radius), pos.add(radius, radius, radius)))) {
            if (e instanceof LivingEntity liv) {
                ClanParticleEffects.applyPoison(liv, 80, 1);
                liv.damage(player.getDamageSources().playerAttack(player), damage * 0.5f);
            }
        }
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_BEE_HURT, SoundCategory.PLAYERS, 0.8f, 0.7f);
        JutsuLogger.logBehavior(def.id(), "cast at " + pos);
    }
}