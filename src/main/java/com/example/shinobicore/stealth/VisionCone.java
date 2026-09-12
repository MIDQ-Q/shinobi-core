package com.example.shinobicore.stealth;
import net.minecraft.entity.LivingEntity;
import net.minecraft.util.math.Vec3d;
public class VisionCone {
    public static boolean canSee(LivingEntity observer, LivingEntity target, float maxDistance, float angleDegrees) {
        if (observer == null || target == null) return false;
        Vec3d look = observer.getRotationVector();
        Vec3d toTarget = target.getPos().subtract(observer.getPos());
        double dist = toTarget.length();
        if (dist > maxDistance) return false;
        // H2: защита от NaN. Math.acos вне [-1,1] даёт NaN, а любое сравнение
        // с NaN == false -> canSee молча возвращал false при пограничных углах.
        if (look.lengthSquared() < 1.0E-6 || toTarget.lengthSquared() < 1.0E-6) return false;
        double dot = look.normalize().dotProduct(toTarget.normalize());
        if (dot < -1.0) dot = -1.0;
        if (dot >  1.0) dot =  1.0;
        double angle = Math.toDegrees(Math.acos(dot));
        return angle <= angleDegrees / 2.0;
    }
}