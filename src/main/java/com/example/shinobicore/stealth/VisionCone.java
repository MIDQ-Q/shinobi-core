package com.example.shinobicore.stealth;
import net.minecraft.entity.LivingEntity;
import net.minecraft.util.math.Vec3d;
public class VisionCone {
    public static boolean canSee(LivingEntity observer, LivingEntity target, float maxDistance, float angleDegrees) {
        Vec3d look = observer.getRotationVector();
        Vec3d toTarget = target.getPos().subtract(observer.getPos());
        double dist = toTarget.length();
        if (dist > maxDistance) return false;
        double angle = Math.toDegrees(Math.acos(look.normalize().dotProduct(toTarget.normalize())));
        return angle <= angleDegrees / 2.0;
    }
}