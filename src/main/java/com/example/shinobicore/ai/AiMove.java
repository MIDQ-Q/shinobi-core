package com.example.shinobicore.ai;

import net.minecraft.entity.mob.MobEntity;
import net.minecraft.util.math.Vec3d;

public class AiMove {

    /**
     * Smooth pursuit: re-issues the path whenever navigation is idle
     * (no stop-start stutter), throttled only while a path is running.
     * If no path can be built - walks directly so the mob never freezes.
     */
    public static void goTo(AiBrain b, Vec3d pos, double speed) {
        if (!(b.entity instanceof MobEntity mob)) return;
        double dist = mob.getPos().distanceTo(pos);
        if (dist < 0.4) { stop(b); return; }
        if (b.navCd > 0 && !mob.getNavigation().isIdle()) return; // path still running
        b.navCd = 8;
        boolean ok = mob.getNavigation().startMovingTo(pos.x, pos.y, pos.z, speed * b.speedMult);
        if (!ok) {
            Vec3d d = pos.subtract(mob.getPos());
            d = new Vec3d(d.x, 0, d.z);
            if (d.lengthSquared() > 1e-6) {
                d = d.normalize().multiply(0.10 * b.speedMult);
                mob.setVelocity(d.x, mob.getVelocity().y, d.z);
                mob.velocityModified = true;
            }
            if (mob.horizontalCollision) { mob.addVelocity(0, 0.4, 0); mob.velocityModified = true; }
        }
    }

    public static void stop(AiBrain b) {
        b.navCd = 0;
        if (b.entity instanceof MobEntity mob) mob.getNavigation().stop();
    }
}