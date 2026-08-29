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

public class ShadowGrabBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        Vec3d pos = player.getPos();

        LivingEntity target = null;
        double minDist = 8;
        for (var e : world.getOtherEntities(player, new net.minecraft.util.math.Box(pos.subtract(8, 4, 8), pos.add(8, 4, 8)))) {
            if (e instanceof LivingEntity liv) {
                double d = liv.distanceTo(player);
                if (d < minDist) { minDist = d; target = liv; }
            }
        }
        if (target != null) {
            ClanParticleEffects.shadowGrab(world, pos, target.getPos());
            ClanParticleEffects.applySlowness(target, 60, 3);
        }
        ClanParticleEffects.shadowTrap(world, pos);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_SOUL_SAND_HIT, SoundCategory.PLAYERS, 1.0f, 0.7f);
        JutsuLogger.logBehavior(def.id(), "cast at " + pos);
    }
}