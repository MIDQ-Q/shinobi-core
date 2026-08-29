package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.tree.TreePassives;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundEvent;
import net.minecraft.sound.SoundCategory;
import net.minecraft.util.Identifier;
import net.minecraft.text.Text;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class GenjutsuBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        float range = params.has("range") ? params.get("range").getAsFloat() : 12.0f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 100;
        int amplifier = params.has("amplifier") ? params.get("amplifier").getAsInt() : 0;
        String effectType = params.has("effect") ? params.get("effect").getAsString() : "fear";

        Vec3d eyePos = player.getEyePos();
        Vec3d lookVec = player.getRotationVector().normalize();

        LivingEntity target = findTarget(serverWorld, player, eyePos, lookVec, range);

        if (target == null) {
            player.sendMessage(Text.literal("\u00a7cNo target in range!"), false);
            JutsuLogger.logBehavior("genjutsu",
                String.format("MISSED: player=%s, range=%.1f",
                    player.getName().getString(), range));
            return;
        }

        float resistChance = calculateResistChance(target, data);
        float roll = serverWorld.getRandom().nextFloat();

        if (roll < resistChance) {
            player.sendMessage(Text.literal(
                "\u00a7e" + target.getName().getString() + " resisted the genjutsu!"), false);
            spawnResistParticles(serverWorld, target);
            JutsuLogger.logBehavior("genjutsu",
                String.format("RESISTED: player=%s, target=%s, resist=%.0f%%, roll=%.2f",
                    player.getName().getString(), target.getName().getString(),
                    resistChance * 100, roll));
            return;
        }

        applyGenjutsuEffect(target, effectType, duration, amplifier);
        spawnGenjutsuParticles(serverWorld, target);

        player.sendMessage(Text.literal(
            "\u00a7aGenjutsu applied to " + target.getName().getString() + "!"), false);

        JutsuLogger.logBehavior("genjutsu",
            String.format("SUCCESS: player=%s, target=%s, effect=%s, dur=%d, amp=%d, resist=%.0f%%",
                player.getName().getString(), target.getName().getString(),
                effectType, duration, amplifier, resistChance * 100));
    }

    private LivingEntity findTarget(ServerWorld world, ServerPlayerEntity player,
                                     Vec3d eyePos, Vec3d lookVec, float range) {
        Box searchBox = player.getBoundingBox().expand(range);
        LivingEntity best = null;
        double bestDist = Double.MAX_VALUE;

        for (Entity entity : world.getOtherEntities(player, searchBox,
                e -> e instanceof LivingEntity && e.isAlive() && e != player)) {
            LivingEntity living = (LivingEntity) entity;
            Vec3d toEntity = living.getPos().add(0, living.getHeight() / 2.0, 0).subtract(eyePos);
            double dist = toEntity.length();
            if (dist > range || dist < 0.5) continue;

            double dot = lookVec.dotProduct(toEntity.normalize());
            if (dot > 0.85 && dist < bestDist) {
                bestDist = dist;
                best = living;
            }
        }
        return best;
    }

    private float calculateResistChance(LivingEntity target, NinjaPlayerData casterData) {
        float baseResist = 0.10f;

        if (target instanceof PlayerEntity playerTarget) {
            try {
                NinjaPlayerData targetData = ((NinjaDataHolder) playerTarget).shinobicore_getData();
                int targetGenjutsuLevel = targetData.getStatLevel(StatType.GENJUTSU);
                baseResist += targetGenjutsuLevel * 0.01f;
            } catch (Exception e) {
                // player without data - base resist only
            }
        }

        int casterGenjutsu = casterData.getStatLevel(StatType.GENJUTSU);
        float pierceBonus = Math.max(0, (casterGenjutsu - 20) * 0.005f);
        // Passive bonus from skill tree
        float passivePierce = TreePassives.collectServer(casterData).genjutsuResist;
        pierceBonus += passivePierce;

        float finalResist = Math.max(0.05f, baseResist - pierceBonus);
        return Math.min(0.90f, finalResist);
    }

    private void applyGenjutsuEffect(LivingEntity target, String effectType,
                                      int duration, int amplifier) {
        switch (effectType) {
            case "fear" -> {
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.SLOWNESS, duration, amplifier + 1, false, false));
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.MINING_FATIGUE, duration, amplifier, false, false));
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.NAUSEA, duration, 0, false, false));
            }
            case "blindness" -> {
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.BLINDNESS, duration, 0, false, false));
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.WEAKNESS, duration, amplifier, false, false));
            }
            case "nightmare" -> {
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.BLINDNESS, duration, 0, false, false));
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.SLOWNESS, duration, amplifier + 1, false, false));
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.WEAKNESS, duration, amplifier, false, false));
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.NAUSEA, duration, 0, false, false));
            }
            case "paralysis" -> {
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.SLOWNESS, duration, 255, false, false));
                target.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.MINING_FATIGUE, duration, 255, false, false));
            }
        }
    }

    private void spawnGenjutsuParticles(ServerWorld world, LivingEntity target) {
        Vec3d pos = target.getPos().add(0, target.getHeight() / 2.0, 0);
        for (int i = 0; i < 30; i++) {
            double angle = (i / 30.0) * Math.PI * 2;
            double r = 0.8 + Math.random() * 0.4;
            world.spawnParticles(ParticleTypes.PORTAL,
                pos.x + Math.cos(angle) * r,
                pos.y + (Math.random() - 0.5) * target.getHeight(),
                pos.z + Math.sin(angle) * r,
                1, (Math.random() - 0.5) * 0.1, Math.random() * 0.2,
                (Math.random() - 0.5) * 0.1, 0.05);
        }
        for (int i = 0; i < 15; i++) {
            world.spawnParticles(ParticleTypes.ENCHANT,
                pos.x + (Math.random() - 0.5) * 1.5,
                pos.y + Math.random() * target.getHeight(),
                pos.z + (Math.random() - 0.5) * 1.5,
                1, 0.1, 0.1, 0.1, 0.08);
        }
    }

    private void spawnResistParticles(ServerWorld world, LivingEntity target) {
        Vec3d pos = target.getPos().add(0, target.getHeight() / 2.0, 0);
        for (int i = 0; i < 20; i++) {
            double angle = (i / 20.0) * Math.PI * 2;
            world.spawnParticles(ParticleTypes.CLOUD,
                pos.x + Math.cos(angle) * 0.6, pos.y, pos.z + Math.sin(angle) * 0.6,
                1, Math.cos(angle) * 0.2, 0.3, Math.sin(angle) * 0.2, 0.1);
        }
    }
}
// PHASE_B_GEN_PASSIVE_USED