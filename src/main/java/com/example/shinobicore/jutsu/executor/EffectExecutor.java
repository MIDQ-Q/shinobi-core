package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.EffectDefinition;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class EffectExecutor {

    public static void applyEffects(ServerPlayerEntity caster, JutsuDefinition jutsu, LivingEntity target) {
        for (EffectDefinition effect : jutsu.getEffects()) {
            applyEffect(caster, effect, target);
        }
    }

    private static void applyEffect(ServerPlayerEntity caster, EffectDefinition effect, LivingEntity target) {
        switch (effect.getType()) {
            case DAMAGE -> applyDamage(caster, effect, target);
            case CONTROL -> applyControl(caster, effect, target);
            case BUFF -> applyBuff(caster, effect, target);
            case DEBUFF -> applyDebuff(caster, effect, target);
            case WORLD -> applyWorld(caster, effect, target);
        }
    }

    private static void applyDamage(ServerPlayerEntity caster, EffectDefinition effect, LivingEntity target) {
        switch (effect.getSubType()) {
            case INSTANT, TRUE_DAMAGE ->
                target.damage(target.getDamageSources().magic(), (float) effect.getDouble("amount", 8));
            case PERCENT ->
                target.damage(target.getDamageSources().magic(),
                    (float) (target.getMaxHealth() * effect.getDouble("percent", 10) / 100.0));
            case DOT, CELLULAR ->
                StatusSystem.addDot(target, effect.getDouble("amount", 2), effect.getInt("duration", 60));
            default -> {}
        }
    }

    private static void applyControl(ServerPlayerEntity caster, EffectDefinition effect, LivingEntity target) {
        int dur = effect.getInt("duration", 40);
        switch (effect.getSubType()) {
            case PUSH -> {
                Vec3d dir = caster != null
                    ? target.getPos().subtract(caster.getPos()).normalize()
                    : new Vec3d(0, 0, 1);
                double force = effect.getDouble("force", 1.5);
                target.addVelocity(dir.x * force, 0.2, dir.z * force);
                target.velocityModified = true;
            }
            case LAUNCH -> {
                target.addVelocity(0, effect.getDouble("force", 1.5) * 0.5, 0);
                target.velocityModified = true;
            }
            case PULL -> {
                if (caster != null) {
                    Vec3d dir = caster.getPos().subtract(target.getPos()).normalize();
                    double force = effect.getDouble("force", 1.5);
                    target.addVelocity(dir.x * force, 0, dir.z * force);
                    target.velocityModified = true;
                }
            }
            case STUN -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, dur, 9, false, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, dur, 9, false, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, dur, 0, false, false, false));
            }
            case ROOT -> {
                double breakDamage = effect.getDouble("breakDamage", 10);
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, dur, 19, false, false, false));
            }
            case SILENCE ->
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, dur, 4, false, false, false));
            case BLIND ->
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, dur, 0, false, false, false));
            default -> {}
        }
    }

    private static void applyBuff(ServerPlayerEntity caster, EffectDefinition effect, LivingEntity target) {
        int dur = effect.getInt("duration", 100);
        switch (effect.getSubType()) {
            case HEAL -> target.heal((float) effect.getDouble("amount", 8));
            case REGEN ->
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.REGENERATION, dur, 1, false, false, false));
            case SHIELD ->
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.ABSORPTION, dur,
                    Math.max(0, (int) (effect.getDouble("amount", 8) / 4.0) - 1), false, false, false));
            case SPEED ->
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SPEED, dur, 1, false, false, false));
            case STRENGTH ->
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.STRENGTH, dur, 1, false, false, false));
            default -> {}
        }
    }

    private static void applyDebuff(ServerPlayerEntity caster, EffectDefinition effect, LivingEntity target) {
        int dur = effect.getInt("duration", 60);
        switch (effect.getSubType()) {
            case BURN -> {
                target.setOnFireFor(Math.max(1, dur / 20));
                StatusSystem.addDot(target, effect.getDouble("dps", 1), dur);
            }
            case SLOW ->
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, dur, 1, false, false, false));
            case WEAKNESS ->
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, dur, 1, false, false, false));
            case POISON ->
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.POISON, dur, 1, false, false, false));
            case BLEED ->
                StatusSystem.addDot(target, effect.getDouble("dps", 1), dur);
            default -> {}
        }
    }

    private static void applyWorld(ServerPlayerEntity caster, EffectDefinition effect, LivingEntity target) {
        // World effects (place_block, ignite, etc.) come in the next iteration
    }
}