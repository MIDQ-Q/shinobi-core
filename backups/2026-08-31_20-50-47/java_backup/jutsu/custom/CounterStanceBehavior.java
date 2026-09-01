package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class CounterStanceBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 3.5f;
        float multiplier = params.has("multiplier") ? params.get("multiplier").getAsFloat() : 2.5f;
        int ticks = 30; // 1.5s window
        player.addStatusEffect(new StatusEffectInstance(StatusEffects.RESISTANCE, ticks, 2, false, false));
        world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 0.8f, 1.2f);
        TickScheduler.schedule(world, 1, 2, ticks / 2, w -> {
            if (player.hurtTime <= 0) return;
            for (Entity e : w.getOtherEntities(player, new Box(player.getPos(), player.getPos()).expand(radius))) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    liv.damage(player.getDamageSources().magic(), damage * multiplier);
                    Vec3d kb = liv.getPos().subtract(player.getPos()).normalize().multiply(1.2);
                    liv.addVelocity(kb.x, 0.4, kb.z);
                    liv.velocityModified = true;
                    w.spawnParticles(ParticleTypes.ENCHANT, liv.getX(), liv.getY() + 1, liv.getZ(), 10, 0.3, 0.3, 0.3, 0.05);
                }
            }
        });
        JutsuLogger.logBehavior("counter_stance", "mult=" + multiplier);
    }
}