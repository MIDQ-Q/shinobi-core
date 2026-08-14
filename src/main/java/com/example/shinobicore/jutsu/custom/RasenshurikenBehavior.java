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
import net.minecraft.text.Text;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.concurrent.atomic.AtomicReference;

public class RasenshurikenBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 8f;
        int chargeTicks = params.has("chargeTicks") ? params.get("chargeTicks").getAsInt() : 60;
        int aoeTicks = params.has("aoeTicks") ? params.get("aoeTicks").getAsInt() : 60;

        player.sendMessage(Text.literal("\u00a7bRasenshuriken charging..."), true);
        world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_AMBIENT, SoundCategory.PLAYERS, 2.0f, 1.5f);

        // Phase 1: Charging (60 ticks = 3s)
        TickScheduler.schedule(world, 1, 2, chargeTicks / 2, w -> {
            Vec3d hand = player.getEyePos().add(player.getRotationVector().multiply(0.8)).add(0, -0.3, 0);
            float scale = 0.5f + 1.5f * ((float) (chargeTicks / 2 - 1) / (chargeTicks / 2));
            for (int i = 0; i < 20; i++) {
                double a = (i / 20.0) * Math.PI * 2 + w.getTime() * 0.3;
                w.spawnParticles(ParticleTypes.CLOUD,
                    hand.x + Math.cos(a) * scale, hand.y + Math.sin(a * 2) * 0.3, hand.z + Math.sin(a) * scale,
                    2, 0.05, 0.05, 0.05, 0.02);
                w.spawnParticles(ParticleTypes.END_ROD,
                    hand.x + Math.cos(a + 0.5) * scale * 0.7, hand.y + Math.sin(a * 3) * 0.2, hand.z + Math.sin(a + 0.5) * scale * 0.7,
                    1, 0.02, 0.02, 0.02, 0.01);
            }
            if (w.getTime() % 20 == 0) {
                world.playSound(null, player.getBlockPos(), SoundEvents.BLOCK_BEACON_POWER_SELECT, SoundCategory.PLAYERS, 1.0f, 0.8f + 0.2f * ((float) (chargeTicks / 2 - 1) / (chargeTicks / 2)));
            }
        });

        // Phase 2: Throw (after charge)
        TickScheduler.schedule(world, chargeTicks + 1, chargeTicks + 1, 1, w -> {
            player.sendMessage(Text.literal("\u00a7aRASENSHURIKEN!"), true);
            world.playSound(null, player.getBlockPos(), SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 2.0f, 1.2f);
            final Vec3d hand = player.getEyePos().add(player.getRotationVector().multiply(0.8));
            final Vec3d vel = player.getRotationVector().multiply(2.5);
            final AtomicReference<Vec3d> posRef = new AtomicReference<>(hand);

            // Travel: 40 ticks (2 seconds)
            TickScheduler.schedule(w, 1, 1, 40, w2 -> {
                Vec3d currentPos = posRef.get().add(vel);
                posRef.set(currentPos);
                // Massive particles while traveling
                for (int i = 0; i < 30; i++) {
                    double a = (i / 30.0) * Math.PI * 2 + w2.getTime() * 0.5;
                    double r = 1.5;
                    w2.spawnParticles(ParticleTypes.CLOUD,
                        currentPos.x + Math.cos(a) * r, currentPos.y + Math.sin(a * 3) * 0.5, currentPos.z + Math.sin(a) * r,
                        3, 0.1, 0.1, 0.1, 0.05);
                }
                // Damage anything close while traveling
                Box travelBox = new Box(currentPos, currentPos).expand(2.5);
                for (Entity e : w2.getOtherEntities(player, travelBox)) {
                    if (e instanceof LivingEntity liv && !liv.equals(player)) {
                        liv.damage(player.getDamageSources().magic(), damage * 0.3f);
                        Vec3d kb = liv.getPos().subtract(currentPos).normalize().multiply(0.3);
                        liv.addVelocity(kb.x, 0.1, kb.z);
                        liv.velocityModified = true;
                    }
                }
            });

            // Phase 3: Expand + AOE (after travel)
            TickScheduler.schedule(w, 42, 2, aoeTicks / 2, w3 -> {
                Vec3d center = posRef.get();
                for (int i = 0; i < 40; i++) {
                    double a = (i / 40.0) * Math.PI * 2 + w3.getTime() * 0.2;
                    double r = radius * ((float) (i % 10) / 10.0);
                    w3.spawnParticles(ParticleTypes.CLOUD,
                        center.x + Math.cos(a) * r, center.y + Math.random() * 2, center.z + Math.sin(a) * r,
                        2, 0.05, 0.1, 0.05, 0.03);
                }
                Box aoeBox = new Box(center, center).expand(radius);
                for (Entity e : w3.getOtherEntities(player, aoeBox)) {
                    if (e instanceof LivingEntity liv && !liv.equals(player)) {
                        liv.damage(player.getDamageSources().magic(), damage * 0.15f);
                        liv.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, 2, false, false));
                        liv.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, 40, 1, false, false));
                    }
                }
            });
        });
        JutsuLogger.logBehavior("rasenshuriken", "charge=" + chargeTicks + " aoe=" + aoeTicks);
    }
}