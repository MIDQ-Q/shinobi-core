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

public class FireSphereBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        Vec3d pos = player.getPos();

        Vec3d look = player.getRotationVector();
        com.example.shinobicore.entity.NinjaProjectileEntity proj =
            new com.example.shinobicore.entity.NinjaProjectileEntity(
                world, player, look.multiply(1.5), damage, 2f, def.nature().getId(), def.id(), 60);
        proj.setPosition(player.getX(), player.getEyeY() - 0.2, player.getZ());
        world.spawnEntity(proj);
        ClanParticleEffects.fireBurst(world, pos, 8);
        world.playSound(null, player.getBlockPos(), SoundEvents.ITEM_FIRECHARGE_USE, SoundCategory.PLAYERS, 1.0f, 1.0f);
        JutsuLogger.logBehavior(def.id(), "cast at " + pos);
    }
}