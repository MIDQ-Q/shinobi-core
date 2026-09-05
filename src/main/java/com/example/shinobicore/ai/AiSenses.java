package com.example.shinobicore.ai;

import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.mob.Monster;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class AiSenses {

    public static LivingEntity findCombatTarget(AiBrain b) {
        ServerWorld world = (ServerWorld) b.entity.getWorld();
        LivingEntity attacker = AiSystem.ownerAttacker(b.owner);
        if (attacker != null && attacker.isAlive() && attacker.distanceTo(b.entity) < 24) return attacker;

        Vec3d origin = b.entity.getPos();
        LivingEntity best = null;
        double bd = 16;
        for (Object o : world.getOtherEntities(b.entity, new Box(origin, origin).expand(16))) {
            if (!(o instanceof LivingEntity e) || !e.isAlive()) continue;
            if (b.owner != null && e.getUuid().equals(b.owner)) continue;
            if (AiSystem.hasBrain(e.getUuid())) continue;
            boolean hostile = o instanceof Monster;
            boolean attacking = b.owner != null && e.getAttacking() != null && e.getAttacking().getUuid().equals(b.owner);
            if (!hostile && !attacking) continue;
            double d = e.getPos().distanceTo(origin);
            if (d < bd) { bd = d; best = e; }
        }
        return best;
    }

    public static LivingEntity findPlayerTarget(AiBrain b) {
        ServerWorld world = (ServerWorld) b.entity.getWorld();
        Vec3d o = b.entity.getPos();
        LivingEntity best = null;
        double bd = 16;
        for (Object obj : world.getOtherEntities(b.entity, new Box(o, o).expand(16))) {
            if (obj instanceof ServerPlayerEntity pl && pl.isAlive() && !pl.isInvisible()) {
                double d = pl.getPos().distanceTo(o);
                if (d < bd) { bd = d; best = pl; }
            }
        }
        return best;
    }
}