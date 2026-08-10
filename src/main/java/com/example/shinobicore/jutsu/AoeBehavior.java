package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
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

public class AoeBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 3.0f;
        String particle = params.has("particle") ? params.get("particle").getAsString() : "explosion";
        int particleCount = params.has("particleCount") ? params.get("particleCount").getAsInt() : 30;
        float knockback = params.has("knockback") ? params.get("knockback").getAsFloat() : 0.3f;

        // Статус-эффект
        String statusEffect = params.has("statusEffect") ? params.get("statusEffect").getAsString() : null;
        int statusDuration = params.has("statusDuration") ? params.get("statusDuration").getAsInt() : 60;
        int statusAmplifier = params.has("statusAmplifier") ? params.get("statusAmplifier").getAsInt() : 0;

        // Оглушение (slowness 255 + mining_fatigue 255 + nausea)
        boolean stun = params.has("stun") && params.get("stun").getAsBoolean();
        int stunDuration = params.has("stunDuration") ? params.get("stunDuration").getAsInt() : 20;

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        Vec3d center = player.getPos().add(0, player.getHeight() / 2.0, 0);

        // Визуальные эффекты
        spawnParticles(serverWorld, center, radius, particle, particleCount);

        // Урон и эффекты по области
        for (Entity entity : serverWorld.getOtherEntities(player, player.getBoundingBox().expand(radius))) {
            if (entity instanceof LivingEntity living && !living.equals(player)) {
                // Урон (может быть 0 для волн без урона)
                if (damage > 0) {
                    living.damage(player.getDamageSources().magic(), damage);
                }

                // Отброс от центра
                if (knockback > 0) {
                    Vec3d toEntity = living.getPos().subtract(center).normalize();
                    Vec3d kb = toEntity.multiply(knockback).add(0, 0.2, 0);
                    living.addVelocity(kb.x, kb.y, kb.z);
                    living.velocityModified = true;
                }

                // Статус-эффект
                if (statusEffect != null) {
                    StatusEffect effect = parseStatusEffect(statusEffect);
                    if (effect != null) {
                        living.addStatusEffect(new StatusEffectInstance(
                                effect, statusDuration, statusAmplifier, false, true));
                    }
                }

                // Оглушение
                if (stun) {
                    living.addStatusEffect(new StatusEffectInstance(
                            StatusEffects.SLOWNESS, stunDuration, 255, false, false));
                    living.addStatusEffect(new StatusEffectInstance(
                            StatusEffects.MINING_FATIGUE, stunDuration, 255, false, false));
                    living.addStatusEffect(new StatusEffectInstance(
                            StatusEffects.NAUSEA, stunDuration, 0, false, false));
                }
            }
        }

        JutsuLogger.logBehavior("aoe", String.format(
                "player=%s, radius=%.1f, damage=%.2f, knockback=%.2f, stun=%b, status=%s",
                player.getName().getString(), radius, damage, knockback, stun, statusEffect));
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

    private void spawnParticles(ServerWorld world, Vec3d center, float radius,
                                 String particle, int count) {
        ParticleEffect particleType = switch (particle) {
            case "fire" -> ParticleTypes.FLAME;
            case "water" -> ParticleTypes.FALLING_WATER;
            case "lightning" -> ParticleTypes.ELECTRIC_SPARK;
            case "wind" -> ParticleTypes.CLOUD;
            case "earth" -> ParticleTypes.POOF;
            case "smoke" -> ParticleTypes.LARGE_SMOKE;
            default -> ParticleTypes.EXPLOSION;
        };

        for (int i = 0; i < count; i++) {
            double angle = (i / (double) count) * Math.PI * 2;
            double r = radius * (0.3 + 0.7 * Math.random());
            double x = center.x + Math.cos(angle) * r;
            double z = center.z + Math.sin(angle) * r;
            double y = center.y + (Math.random() - 0.5) * radius;

            world.spawnParticles(particleType, x, y, z, 1,
                    (Math.random() - 0.5) * 0.2,
                    Math.random() * 0.3,
                    (Math.random() - 0.5) * 0.2,
                    0.05);
        }
    }
}