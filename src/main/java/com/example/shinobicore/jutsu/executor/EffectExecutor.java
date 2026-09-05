package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.EffectDefinition;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class EffectExecutor {

    public static void applyEffects(CastContext ctx, LivingEntity target) {
        for (EffectDefinition effect : ctx.effects) {
            applyEffect(ctx, effect, target);
        }
    }

    private static void applyEffect(CastContext ctx, EffectDefinition effect, LivingEntity target) {
        VerificationLogger.logEffect(ctx.jutsu.getId(), effect.getType().getId(), effect.getSubType().getId(), "");
        switch (effect.getType()) {
            case DAMAGE -> applyDamage(ctx, effect, target);
            case CONTROL -> applyControl(ctx, effect, target);
            case BUFF -> applyBuff(ctx, effect, target);
            case DEBUFF -> applyDebuff(ctx, effect, target);
            case WORLD -> WorldEffectExecutor.applyWorld(ctx, effect, target.getPos());
        }
    }

    private static void applyDamage(CastContext ctx, EffectDefinition effect, LivingEntity target) {
        float scale = (float) ctx.damageScale;
        switch (effect.getSubType()) {
            case INSTANT, TRUE_DAMAGE ->
                    Combat.applyDamage(ctx, target, (float) effect.getDouble("amount", 8) * scale);
            case PERCENT ->
                    Combat.applyDamage(ctx, target, (float) (target.getMaxHealth() * effect.getDouble("percent", 10) / 100.0));
            case DOT, CELLULAR ->
                    StatusSystem.addDot(target, effect.getDouble("amount", 2) * scale, effect.getInt("duration", 60));
            default -> {}
        }
    }

    private static void applyControl(CastContext ctx, EffectDefinition effect, LivingEntity target) {
        int dur = effect.getInt("duration", 40);
        switch (effect.getSubType()) {
            case PUSH -> {
                Vec3d dir = target.getPos().subtract(ctx.caster.getPos()).normalize();
                double f = effect.getDouble("force", 1.5);
                target.addVelocity(dir.x * f, 0.2, dir.z * f);
                target.velocityModified = true;
            }
            case LAUNCH -> { target.addVelocity(0, effect.getDouble("force", 1.5) * 0.5, 0); target.velocityModified = true; }
            case PULL -> {
                Vec3d dir = ctx.caster.getPos().subtract(target.getPos()).normalize();
                double f = effect.getDouble("force", 1.5);
                target.addVelocity(dir.x * f, 0, dir.z * f);
                target.velocityModified = true;
            }
            case STUN -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, dur, 9, false, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, dur, 9, false, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, dur, 0, false, false, false));
            }
            case ROOT -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, dur, 19, false, false, false));
            case SILENCE -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, dur, 4, false, false, false));
            case BLIND -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, dur, 0, false, false, false));
            case FEAR -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.NAUSEA, dur, 1, false, false, false));
                Vec3d away = target.getPos().subtract(ctx.caster.getPos()).normalize();
                target.addVelocity(away.x * 0.8, 0.1, away.z * 0.8);
                target.velocityModified = true;
            }
            case CONFUSION -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.NAUSEA, dur, 2, false, false, false));
                target.addVelocity((target.getRandom().nextFloat() - 0.5), 0.2, (target.getRandom().nextFloat() - 0.5));
                target.velocityModified = true;
            }
            case SLEEP -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, dur, 255, false, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, dur, 0, false, false, false));
            }
            case PARALYSIS -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, dur, 255, false, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, dur, 255, false, false, false));
            }
            case SLOW -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, dur, effect.getInt("percent", 30) >= 50 ? 2 : 1, false, false, false));
            default -> {}
        }
    }

    private static void applyBuff(CastContext ctx, EffectDefinition effect, LivingEntity target) {
        int dur = effect.getInt("duration", 100);
        switch (effect.getSubType()) {
            case HEAL -> target.heal((float) effect.getDouble("amount", 8));
            case REGEN -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.REGENERATION, dur, 1, false, false, false));
            case SHIELD -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.ABSORPTION, dur,
                    Math.max(0, (int) (effect.getDouble("amount", 8) / 4.0) - 1), false, false, false));
            case SPEED -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.SPEED, dur, 1, false, false, false));
            case STRENGTH -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.STRENGTH, dur, 1, false, false, false));
            case INVISIBILITY -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.INVISIBILITY, dur, 0, false, false, false));
            case HASTE -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.HASTE, dur, 1, false, false, false));
                if (target instanceof ServerPlayerEntity sp) {
                    CooldownSystem.reduceAll(sp.getUuid(), dur / 2);
                }
            }
            case CHAKRA_REGEN -> {
                if (target instanceof ServerPlayerEntity sp) {
                    NinjaPlayerData data = ((NinjaDataHolder) sp).shinobicore_getData();
                    data.setCurrentChakra((float) (data.getCurrentChakra() + effect.getDouble("rate", 1) * dur / 20.0));
                }
            }
            case PURIFY -> StatusSystem.purify(target);
            default -> {}
        }
    }

    private static void applyDebuff(CastContext ctx, EffectDefinition effect, LivingEntity target) {
        int dur = effect.getInt("duration", 60);
        switch (effect.getSubType()) {
            case BURN -> {
                target.setOnFireFor(Math.max(1, dur / 20));
                StatusSystem.addDot(target, effect.getDouble("dps", 1), dur);
            }
            case SLOW -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, dur, 1, false, false, false));
            case WEAKNESS -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, dur, 1, false, false, false));
            case POISON -> target.addStatusEffect(new StatusEffectInstance(StatusEffects.POISON, dur, 1, false, false, false));
            case BLEED -> StatusSystem.addDot(target, effect.getDouble("dps", 1), dur);
            case VULNERABILITY -> {
                StatusSystem.addVulnerability(target, effect.getDouble("percent", 20), dur);
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, dur, 0, false, false, false));
            }
            case CURSE -> StatusSystem.addCurse(target, effect.getDouble("dps", 1), dur);
            case EXHAUSTION -> {
                if (target instanceof ServerPlayerEntity sp) {
                    NinjaPlayerData data = ((NinjaDataHolder) sp).shinobicore_getData();
                    data.setFatigue((float) (data.getFatigue() + effect.getDouble("amount", 10)));
                }
            }
            case CHAKRA_DRAIN -> {
                if (target instanceof ServerPlayerEntity tp) {
                    NinjaPlayerData td = ((NinjaDataHolder) tp).shinobicore_getData();
                    double drain = effect.getDouble("rate", 1) * dur / 20.0;
                    td.setCurrentChakra((float) Math.max(0, td.getCurrentChakra() - drain));
                    NinjaPlayerData cd = ((NinjaDataHolder) ctx.caster).shinobicore_getData();
                    cd.setCurrentChakra((float) (cd.getCurrentChakra() + drain));
                }
            }
            default -> {}
        }
    }
}