package com.example.shinobicore.combat;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;
public class ThrowingHelper {
    public static double assistConeDeg(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        double cone = 3.0 + data.getStatLevel(StatType.PERCEPTION) * 0.12;
        if (data.isNodeUnlocked("shuriken_accuracy")) cone += 5.0;
        return cone;
    }
    public static float assistBlend(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return (float) Math.min(1.0, 0.5 + data.getStatLevel(StatType.PERCEPTION) / 200.0);
    }
    public static long markDurationMs(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return data.isNodeUnlocked("shuriken_mark") ? 15000 : 10000;
    }
    public static boolean doubleThrow(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return data.isNodeUnlocked("shuriken_double");
    }
    public static Vec3d aimAssist(ServerPlayerEntity player, Vec3d dir, double range) {
        double coneRad = Math.toRadians(assistConeDeg(player));
        Vec3d eye = player.getEyePos();
        Vec3d flat = dir.normalize();
        LivingEntity best = null;
        double bestAngle = Double.MAX_VALUE;
        for (LivingEntity e : player.getWorld().getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(range), t -> t != player && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() * 0.6, 0).subtract(eye);
            double dist = to.length();
            if (dist > range || dist < 0.5) continue;
            double angle = Math.acos(Math.max(-1, Math.min(1, flat.dotProduct(to.normalize()))));
            if (angle <= coneRad && angle < bestAngle) { bestAngle = angle; best = e; }
        }
        if (best == null) return dir;
        Vec3d toTarget = best.getPos().add(0, best.getHeight() * 0.6, 0).subtract(eye).normalize();
        return flat.lerp(toTarget, assistBlend(player)).normalize();
    }
}