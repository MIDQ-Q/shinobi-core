package com.example.shinobicore.combat;

import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

/**
 * Kenjutsu damage/cooldown formulas.
 * Combo: 6 steps (0-5). Step 5 = finisher (360 AOE).
 * Special attacks: JUMP (airborne), SPRINT (sprinting).
 */
public class KenjutsuFormulas {
    // 6-step combo multipliers
    private static final float[] STEP_MULT = {1.0f, 1.0f, 1.15f, 1.3f, 1.5f, 2.2f};
    private static final float[] STEP_KB   = {0.3f, 0.3f, 0.35f, 0.4f, 0.6f, 1.4f};
    public static final int MAX_COMBO_STEPS = 6;

    // Special attack multipliers
    private static final float JUMP_MULT = 2.5f;
    private static final float JUMP_KB = 1.8f;
    private static final float SPRINT_MULT = 1.6f;
    private static final float SPRINT_KB = 1.0f;

    public static float baseDamage(int taiLevel) { return 6.0f + taiLevel * 0.35f; }

    public static float computeDamage(int taiLevel, KenjutsuStance stance,
                                      boolean chakraMode, int step, boolean exhausted) {
        int clampedStep = Math.max(0, Math.min(MAX_COMBO_STEPS - 1, step));
        float d = baseDamage(taiLevel) * STEP_MULT[clampedStep] * stance.getDamageMult();
        if (chakraMode) d *= stance.getChakraDamageMult();
        if (exhausted) d *= 0.5f;
        return d;
    }

    public static float computeJumpDamage(int taiLevel, KenjutsuStance stance,
                                          boolean chakraMode, boolean exhausted) {
        float d = baseDamage(taiLevel) * JUMP_MULT * stance.getDamageMult();
        if (chakraMode) d *= stance.getChakraDamageMult();
        if (exhausted) d *= 0.5f;
        return d;
    }

    public static float computeSprintDamage(int taiLevel, KenjutsuStance stance,
                                            boolean chakraMode, boolean exhausted) {
        float d = baseDamage(taiLevel) * SPRINT_MULT * stance.getDamageMult();
        if (chakraMode) d *= stance.getChakraDamageMult();
        if (exhausted) d *= 0.5f;
        return d;
    }

    public static long cooldownMs(KenjutsuStance stance) {
        return Math.max(180, (long)(450 / stance.getSpeedMult()));
    }

    public static long jumpCooldownMs() { return 900; }
    public static long sprintCooldownMs() { return 600; }

    public static float getKnockback(int step) {
        return STEP_KB[Math.max(0, Math.min(MAX_COMBO_STEPS - 1, step))];
    }

    public static float getJumpKnockback() { return JUMP_KB; }
    public static float getSprintKnockback() { return SPRINT_KB; }

    public static float getFatiguePerHit(KenjutsuStance stance) {
        return 1.5f * stance.getFatigueMult();
    }

    public static float getJumpFatigue() { return 4.0f; }
    public static float getSprintFatigue() { return 2.5f; }

    public static List<LivingEntity> findTargetsInCone(ServerWorld world, LivingEntity attacker,
                                                        Vec3d look, double range, double angleDeg) {
        List<LivingEntity> out = new ArrayList<>();
        Vec3d dir = look.normalize();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class,
                attacker.getBoundingBox().expand(range + 1), t -> t != attacker && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() / 2.0, 0)
                    .subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
            if (to.length() > range) continue;
            double dot = dir.dotProduct(to.normalize());
            if (Math.toDegrees(Math.acos(Math.max(-1, Math.min(1, dot)))) <= angleDeg / 2) out.add(e);
        }
        return out;
    }

    public static List<LivingEntity> findInRadius(ServerWorld world, LivingEntity attacker, double range) {
        List<LivingEntity> out = new ArrayList<>();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class,
                attacker.getBoundingBox().expand(range), t -> t != attacker && t.isAlive())) {
            if (e.getPos().distanceTo(attacker.getPos()) <= range) out.add(e);
        }
        return out;
    }
}