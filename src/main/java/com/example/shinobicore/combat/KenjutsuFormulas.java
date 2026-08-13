package com.example.shinobicore.combat;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;
public class KenjutsuFormulas {
    private static final float[] STEP_MULT = {1.0f, 1.0f, 1.2f, 1.8f};
    private static final float[] STEP_KB = {0.3f, 0.3f, 0.4f, 1.2f};
    public static float baseDamage(int taiLevel) { return 6.0f + taiLevel * 0.35f; }
    public static float computeDamage(int taiLevel, KenjutsuStance stance, boolean chakraMode, int step, boolean exhausted) {
        float d = baseDamage(taiLevel) * STEP_MULT[Math.max(0, Math.min(3, step))] * stance.getDamageMult();
        if (chakraMode) d *= 1.2f;
        if (exhausted) d *= 0.5f;
        return d;
    }
    public static long cooldownMs(KenjutsuStance stance) {
        return Math.max(200, (long)(450 / stance.getSpeedMult()));
    }
    public static float getKnockback(int step) { return STEP_KB[Math.max(0, Math.min(3, step))]; }
    public static List<LivingEntity> findTargetsInCone(ServerWorld world, LivingEntity attacker, Vec3d look, double range, double angleDeg) {
        List<LivingEntity> out = new ArrayList<>();
        Vec3d dir = look.normalize();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class, attacker.getBoundingBox().expand(range + 1),
                t -> t != attacker && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() / 2.0, 0).subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
            if (to.length() > range) continue;
            double dot = dir.dotProduct(to.normalize());
            if (Math.toDegrees(Math.acos(Math.max(-1, Math.min(1, dot)))) <= angleDeg / 2) out.add(e);
        }
        return out;
    }
    public static List<LivingEntity> findInRadius(ServerWorld world, LivingEntity attacker, double range) {
        List<LivingEntity> out = new ArrayList<>();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class, attacker.getBoundingBox().expand(range),
                t -> t != attacker && t.isAlive())) {
            if (e.getPos().distanceTo(attacker.getPos()) <= range) out.add(e);
        }
        return out;
    }
}