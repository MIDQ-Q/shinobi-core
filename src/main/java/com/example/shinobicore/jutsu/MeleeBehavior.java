package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
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

public class MeleeBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        float range = params.has("range") ? params.get("range").getAsFloat() : 3.0f;
        float coneAngleDeg = params.has("coneAngle") ? params.get("coneAngle").getAsFloat() : 120.0f;
        float knockback = params.has("knockback") ? params.get("knockback").getAsFloat() : 0.4f;
        boolean fullCircle = params.has("fullCircle") && params.get("fullCircle").getAsBoolean();

        // Поджиг
        boolean ignite = params.has("ignite") && params.get("ignite").getAsBoolean();
        int igniteDuration = params.has("igniteDuration") ? params.get("igniteDuration").getAsInt() : 3;

        // Статус-эффект
        String statusEffect = params.has("statusEffect") ? params.get("statusEffect").getAsString() : null;
        int statusDuration = params.has("statusDuration") ? params.get("statusDuration").getAsInt() : 60;
        int statusAmplifier = params.has("statusAmplifier") ? params.get("statusAmplifier").getAsInt() : 0;

        // Частицы
        String particle = params.has("particle") ? params.get("particle").getAsString() : null;
        int particleCount = params.has("particleCount") ? params.get("particleCount").getAsInt() : 20;

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        Vec3d lookDir = player.getRotationVector();

        // Ищем цели
        List<LivingEntity> targets;
        if (fullCircle) {
            targets = findTargetsInRadius(serverWorld, player, range);
        } else {
            targets = findTargetsInCone(serverWorld, player, lookDir, range, coneAngleDeg);
        }

        for (LivingEntity target : targets) {
            // Урон
            target.damage(player.getDamageSources().magic(), damage);

            // Отброс
            Vec3d kb = target.getPos().subtract(player.getPos()).normalize().multiply(knockback);
            target.addVelocity(kb.x, 0.2, kb.z);
            target.velocityModified = true;

            // Поджиг
            if (ignite) {
                target.setOnFireFor(igniteDuration);
            }

            // Статус-эффект
            if (statusEffect != null) {
                StatusEffect effect = parseStatusEffect(statusEffect);
                if (effect != null) {
                    target.addStatusEffect(new StatusEffectInstance(
                            effect, statusDuration, statusAmplifier, false, true));
                }
            }
        }

        // Частицы
        if (particle != null) {
            spawnMeleeParticles(serverWorld, player, lookDir, range, particle, particleCount);
        }

        JutsuLogger.logBehavior("melee", String.format(
                "player=%s, targets=%d, range=%.1f, cone=%.0f, fullCircle=%b, ignite=%b",
                player.getName().getString(), targets.size(), range, coneAngleDeg, fullCircle, ignite));
    }

    private List<LivingEntity> findTargetsInCone(ServerWorld world, ServerPlayerEntity attacker,
                                                  Vec3d lookDir, float range, float coneAngleDeg) {
        List<LivingEntity> targets = new ArrayList<>();
        if (lookDir.lengthSquared() < 0.001) return targets;

        Vec3d dir = lookDir.normalize();
        var searchBox = attacker.getBoundingBox().expand(range + 1.0);
        List<LivingEntity> entities = world.getEntitiesByClass(LivingEntity.class, searchBox,
                e -> e != attacker && e.isAlive());

        for (LivingEntity target : entities) {
            Vec3d toTarget = target.getPos().add(0, target.getHeight() / 2.0, 0)
                    .subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
            if (toTarget.length() > range) continue;

            double dot = dir.dotProduct(toTarget.normalize());
            double angle = Math.toDegrees(Math.acos(Math.max(-1.0, Math.min(1.0, dot))));

            if (angle <= coneAngleDeg / 2.0) {
                targets.add(target);
            }
        }
        return targets;
    }

    private List<LivingEntity> findTargetsInRadius(ServerWorld world, ServerPlayerEntity attacker,
                                                    float range) {
        List<LivingEntity> targets = new ArrayList<>();
        var searchBox = attacker.getBoundingBox().expand(range);
        List<LivingEntity> entities = world.getEntitiesByClass(LivingEntity.class, searchBox,
                e -> e != attacker && e.isAlive());
        for (LivingEntity target : entities) {
            if (target.getPos().distanceTo(attacker.getPos()) <= range) {
                targets.add(target);
            }
        }
        return targets;
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

    private void spawnMeleeParticles(ServerWorld world, ServerPlayerEntity player, Vec3d lookDir,
                                      float range, String particle, int count) {
        ParticleEffect particleType = switch (particle) {
            case "fire" -> ParticleTypes.FLAME;
            case "water" -> ParticleTypes.FALLING_WATER;
            case "lightning" -> ParticleTypes.ELECTRIC_SPARK;
            case "wind" -> ParticleTypes.CLOUD;
            case "earth" -> ParticleTypes.POOF;
            case "smoke" -> ParticleTypes.LARGE_SMOKE;
            default -> ParticleTypes.CRIT;
        };

        Vec3d startPos = player.getPos().add(0, player.getHeight() * 0.7, 0);
        Vec3d dir = lookDir.normalize();

        for (int i = 0; i < count; i++) {
            float progress = (float) i / count;
            float distance = progress * range;
            Vec3d pos = startPos.add(dir.multiply(distance));

            double offsetX = (Math.random() - 0.5) * 0.8;
            double offsetY = (Math.random() - 0.5) * 0.8;
            double offsetZ = (Math.random() - 0.5) * 0.8;

            world.spawnParticles(particleType,
                    pos.x + offsetX, pos.y + offsetY, pos.z + offsetZ,
                    1, 0, 0, 0, 0.02);
        }
    }
}