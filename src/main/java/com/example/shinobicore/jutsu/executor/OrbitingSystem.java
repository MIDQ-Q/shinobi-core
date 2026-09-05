package com.example.shinobicore.jutsu.executor;

import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class OrbitingSystem {

    private static class Orbiter {
        final CastContext ctx;
        final double radius;
        final int count;
        int ticksLeft;
        int angle;
        Orbiter(CastContext ctx, double radius, int count, int duration) {
            this.ctx = ctx; this.radius = radius; this.count = count;
            this.ticksLeft = duration; this.angle = 0;
        }
    }

    private static final List<Orbiter> ACTIVE = new ArrayList<>();

    public static void start(CastContext ctx, double radius, int count, int duration) {
        ACTIVE.add(new Orbiter(ctx, radius, count, duration));
    }

    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Orbiter> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Orbiter o = it.next();
            if (!o.ctx.caster.isAlive()) { it.remove(); continue; }
            ServerWorld world = o.ctx.world();
            Vec3d center = o.ctx.caster.getPos().add(0, 1, 0);
            o.angle++;
            for (int i = 0; i < o.count; i++) {
                double a = (o.angle * 0.1) + (i * 2 * Math.PI / o.count);
                Vec3d pos = center.add(Math.cos(a) * o.radius, 0, Math.sin(a) * o.radius);
                Fx.trail(world, pos, o.ctx.jutsu.getElement());
                // Damage nearby enemies
                for (Object e : world.getOtherEntities(o.ctx.caster, new net.minecraft.util.math.Box(pos, pos).expand(0.5))) {
                    if (e instanceof LivingEntity le && le.isAlive() && !le.equals(o.ctx.caster)) {
                        if (o.ctx.markHit(le)) {
                            EffectExecutor.applyEffects(o.ctx, le);
                        }
                    }
                }
            }
            o.ticksLeft--;
            if (o.ticksLeft <= 0) it.remove();
        }
    }
}