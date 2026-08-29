package com.example.shinobicore.combat;

import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

public class MeleeHitDetection {
    public static final double RANGE = 3.0;
    public static final double CONE_ANGLE_DEG = 120.0;

    public static List<LivingEntity> findTargetsInCone(ServerWorld world, PlayerEntity attacker, Vec3d lookDir) {
        List<LivingEntity> targets = new ArrayList<>();
        if (lookDir.lengthSquared() < 0.001) return targets;
        Vec3d dir = lookDir.normalize();

        Box searchBox = attacker.getBoundingBox().expand(RANGE + 1.0);
        List<LivingEntity> entities = world.getEntitiesByClass(LivingEntity.class, searchBox,
            e -> e != attacker && e.isAlive());

        for (LivingEntity target : entities) {
            Vec3d toTarget = target.getPos().add(0, target.getHeight() / 2.0, 0)
                .subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
            if (toTarget.length() > RANGE) continue;
            double dot = dir.dotProduct(toTarget.normalize());
            double angle = Math.toDegrees(Math.acos(Math.max(-1.0, Math.min(1.0, dot))));
            if (angle <= CONE_ANGLE_DEG / 2.0) {
                targets.add(target);
            }
        }
        return targets;
    }

    public static void applyDamage(ServerWorld world, PlayerEntity attacker,
                                   List<LivingEntity> targets, float damage, float knockback) {
        for (LivingEntity target : targets) {
            target.damage(world.getDamageSources().playerAttack(attacker), damage);
            Vec3d kb = target.getPos().subtract(attacker.getPos()).normalize().multiply(knockback);
            target.addVelocity(kb.x, 0.15, kb.z);
            target.velocityModified = true;
        }
    }
}