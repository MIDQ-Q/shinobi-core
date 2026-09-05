package com.example.shinobicore.jutsu.executor;

import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class StickSystem {

    private static class Stuck {
        final CastContext ctx;
        final LivingEntity target;
        final Vec3d offset;
        int ticksLeft;
        Stuck(CastContext ctx, LivingEntity target, Vec3d offset, int duration) {
            this.ctx = ctx; this.target = target; this.offset = offset; this.ticksLeft = duration;
        }
    }

    private static final List<Stuck> ACTIVE = new ArrayList<>();

    public static void stick(CastContext ctx, LivingEntity target, int duration) {
        Vec3d offset = target.getPos().subtract(ctx.caster.getPos()).normalize().multiply(0.5);
        ACTIVE.add(new Stuck(ctx, target, offset, duration));
    }

    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Stuck> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Stuck s = it.next();
            if (!s.target.isAlive()) { it.remove(); continue; }
            Vec3d pos = s.target.getPos().add(s.offset);
            Fx.trail(s.ctx.world(), pos, s.ctx.jutsu.getElement());
            s.ticksLeft--;
            if (s.ticksLeft <= 0) {
                Fx.elementBurst(s.ctx.world(), pos, s.ctx.jutsu.getElement(), 15);
                it.remove();
            }
        }
    }
}