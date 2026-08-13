package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.combat.MarkTracker;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffect;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

public class DashBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        float distance = params.has("distance") ? params.get("distance").getAsFloat() : 5.0f;
        float knockback = params.has("knockback") ? params.get("knockback").getAsFloat() : 0.5f;
        float hitRadius = params.has("hitRadius") ? params.get("hitRadius").getAsFloat() : 1.0f;
        float waveWidth = params.has("waveWidth") ? params.get("waveWidth").getAsFloat() : 0f;

        // Статус-эффект
        String statusEffect = params.has("statusEffect") ? params.get("statusEffect").getAsString() : null;
        int statusDuration = params.has("statusDuration") ? params.get("statusDuration").getAsInt() : 60;
        int statusAmplifier = params.has("statusAmplifier") ? params.get("statusAmplifier").getAsInt() : 0;

        // Частицы вдоль пути
        String particle = params.has("particle") ? params.get("particle").getAsString() : null;
        int particleCount = params.has("particleCount") ? params.get("particleCount").getAsInt() : 20;

        // === НОВОЕ: Trail-частицы (брызги воды) ===
        String trailParticle = params.has("trailParticle") ? params.get("trailParticle").getAsString() : null;
        int trailCount = params.has("trailCount") ? params.get("trailCount").getAsInt() : 0;

        // === НОВОЕ: Splash при приземлении ===
        boolean splashOnLand = params.has("splashOnLand") && params.get("splashOnLand").getAsBoolean();
        float splashRadius = params.has("splashRadius") ? params.get("splashRadius").getAsFloat() : 3.0f;
        float splashDamage = params.has("splashDamage") ? params.get("splashDamage").getAsFloat() : 0f;

        Vec3d look = player.getRotationVector();
        Vec3d startPos = player.getPos();
        Vec3d endPos = startPos.add(look.multiply(distance));

        // Перемещаем игрока
        player.addVelocity(look.x * distance * 0.5, 0.1, look.z * distance * 0.5);
        player.velocityModified = true;

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        // Ищем мобов на пути рывка
        List<LivingEntity> targets = findEntitiesOnPath(
                serverWorld, player, startPos, endPos, hitRadius, waveWidth);

        for (LivingEntity target : targets) {
            if (damage > 0) {
                target.damage(player.getDamageSources().magic(), MarkTracker.boost(target, damage));
            }

            Vec3d toTarget = target.getPos().subtract(startPos).normalize();
            Vec3d kb = toTarget.multiply(knockback).add(0, 0.3, 0);
            target.addVelocity(kb.x, kb.y, kb.z);
            target.velocityModified = true;

            if (statusEffect != null) {
                StatusEffect effect = parseStatusEffect(statusEffect);
                if (effect != null) {
                    target.addStatusEffect(new StatusEffectInstance(
                            effect, statusDuration, statusAmplifier, false, true));
                }
            }
        }

        // === НОВОЕ: Trail-частицы (брызги вдоль пути) ===
        if (trailParticle != null && trailCount > 0) {
            spawnTrailParticles(serverWorld, startPos, endPos, trailParticle, trailCount);
        }

        // Частицы вдоль траектории
        if (particle != null) {
            spawnDashParticles(serverWorld, startPos, endPos, particle, particleCount);
        }

        // === НОВОЕ: Splash при приземлении ===
        if (splashOnLand) {
            spawnSplashAtEnd(serverWorld, endPos, splashRadius, splashDamage, player);
        }

        JutsuLogger.logBehavior("dash", String.format(
                "player=%s, targets=%d, distance=%.1f, knockback=%.2f, waveWidth=%.1f, trail=%b, splash=%b",
                player.getName().getString(), targets.size(), distance, knockback,
                waveWidth, trailParticle != null, splashOnLand));
    }

    private List<LivingEntity> findEntitiesOnPath(ServerWorld world, ServerPlayerEntity attacker,
                                                   Vec3d start, Vec3d end,
                                                   float radius, float waveWidth) {
        List<LivingEntity> targets = new ArrayList<>();
        Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);
        float effectiveRadius = radius + waveWidth;

        for (float d = 0; d <= length; d += 0.5f) {
            Vec3d checkPos = start.add(dir.multiply(d));
            for (Entity entity : world.getOtherEntities(attacker,
                    attacker.getBoundingBox().expand(effectiveRadius + 1.0)
                            .offset(checkPos.subtract(attacker.getPos())))) {
                if (entity instanceof LivingEntity living
                        && !living.equals(attacker) && living.isAlive()) {
                    if (living.getPos().distanceTo(checkPos) <= effectiveRadius + 0.5) {
                        if (!targets.contains(living)) {
                            targets.add(living);
                        }
                    }
                }
            }
        }
        return targets;
    }

    // === НОВОЕ: Trail-частицы (брызги воды вдоль пути) ===
    private void spawnTrailParticles(ServerWorld world, Vec3d start, Vec3d end,
                                      String particle, int count) {
        ParticleEffect particleType = switch (particle) {
            case "water" -> ParticleTypes.FALLING_WATER;
            case "fire" -> ParticleTypes.FLAME;
            case "wind" -> ParticleTypes.CLOUD;
            case "earth" -> ParticleTypes.POOF;
            case "lightning" -> ParticleTypes.ELECTRIC_SPARK;
            default -> ParticleTypes.FALLING_WATER;
        };

        Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);

        for (int i = 0; i < count; i++) {
            float progress = (float) i / count;
            Vec3d pos = start.add(dir.multiply(progress * length));

            // Разброс в стороны (брызги летят вбок)
            double spreadX = (Math.random() - 0.5) * 2.5;
            double spreadY = Math.random() * 1.5;
            double spreadZ = (Math.random() - 0.5) * 2.5;

            world.spawnParticles(particleType,
                    pos.x + spreadX, pos.y + 0.3 + spreadY, pos.z + spreadZ,
                    1, 0.15, 0.3, 0.15, 0.08);
        }

        // Дополнительные "брызги вверх" для эффекта водопада
        for (int i = 0; i < count / 3; i++) {
            float progress = (float) i / (count / 3);
            Vec3d pos = start.add(dir.multiply(progress * length));

            world.spawnParticles(ParticleTypes.SPLASH,
                    pos.x + (Math.random() - 0.5) * 2.0,
                    pos.y + 0.5,
                    pos.z + (Math.random() - 0.5) * 2.0,
                    2, 0.3, 0.5, 0.3, 0.1);
        }
    }

    // === НОВОЕ: Splash при приземлении ===
    private void spawnSplashAtEnd(ServerWorld world, Vec3d endPos, float radius,
                                   float splashDamage, ServerPlayerEntity player) {
        // Визуал: кольцо брызг
        int ringCount = 30;
        for (int i = 0; i < ringCount; i++) {
            double angle = (i / (double) ringCount) * Math.PI * 2;
            double x = endPos.x + Math.cos(angle) * radius;
            double z = endPos.z + Math.sin(angle) * radius;

            world.spawnParticles(ParticleTypes.FALLING_WATER, x, endPos.y + 0.5, z,
                    3, 0.2, 0.4, 0.2, 0.1);
            world.spawnParticles(ParticleTypes.SPLASH, x, endPos.y + 0.3, z,
                    2, 0.3, 0.5, 0.3, 0.12);
        }

        // Урон по области при приземлении
        if (splashDamage > 0) {
            for (Entity entity : world.getOtherEntities(player,
                    player.getBoundingBox().expand(radius))) {
                if (entity instanceof LivingEntity living && !living.equals(player)) {
                    living.damage(player.getDamageSources().magic(), splashDamage);
                    Vec3d kb = living.getPos().subtract(endPos).normalize().multiply(0.8);
                    living.addVelocity(kb.x, 0.4, kb.z);
                    living.velocityModified = true;
                }
            }
        }
    }

    private StatusEffect parseStatusEffect(String id) {
        return switch (id) {
            case "slowness" -> StatusEffects.SLOWNESS;
            case "weakness" -> StatusEffects.WEAKNESS;
            case "poison" -> StatusEffects.POISON;
            case "wither" -> StatusEffects.WITHER;
            case "blindness" -> StatusEffects.BLINDNESS;
            case "nausea" -> StatusEffects.NAUSEA;
            case "mining_fatigue" -> StatusEffects.MINING_FATIGUE;
            case "levitation" -> StatusEffects.LEVITATION;
            case "glowing" -> StatusEffects.GLOWING;
            default -> null;
        };
    }

    private void spawnDashParticles(ServerWorld world, Vec3d start, Vec3d end,
                                     String particle, int count) {
        ParticleEffect particleType = switch (particle) {
            case "fire" -> ParticleTypes.FLAME;
            case "water" -> ParticleTypes.FALLING_WATER;
            case "lightning" -> ParticleTypes.ELECTRIC_SPARK;
            case "wind" -> ParticleTypes.CLOUD;
            case "earth" -> ParticleTypes.POOF;
            case "smoke" -> ParticleTypes.LARGE_SMOKE;
            default -> ParticleTypes.CLOUD;
        };

        Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);

        for (int i = 0; i < count; i++) {
            float progress = (float) i / count;
            Vec3d pos = start.add(dir.multiply(progress * length));

            double offsetX = (Math.random() - 0.5) * 1.5;
            double offsetY = (Math.random() - 0.5) * 0.8;
            double offsetZ = (Math.random() - 0.5) * 1.5;

            world.spawnParticles(particleType,
                    pos.x + offsetX, pos.y + 0.5 + offsetY, pos.z + offsetZ,
                    2, 0.1, 0.15, 0.1, 0.06);
        }
    }
}