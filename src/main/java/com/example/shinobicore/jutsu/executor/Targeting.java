package com.example.shinobicore.jutsu.executor;

import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class Targeting {

    public static LivingEntity lookEntity(ServerPlayerEntity player, double range) {
        Vec3d look = player.getRotationVector();
        LivingEntity best = null;
        double bestDot = 0.6;
        for (Object o : player.getServerWorld().getOtherEntities(player, player.getBoundingBox().expand(range))) {
            if (!(o instanceof LivingEntity e) || !e.isAlive()) continue;
            Vec3d to = e.getPos().add(0, e.getHeight() / 2.0, 0).subtract(player.getEyePos()).normalize();
            double dot = to.dotProduct(look);
            if (dot > bestDot) { bestDot = dot; best = e; }
        }
        return best;
    }
}