package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.FormDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.*;

public class ZoneSystem {
    private static class Zone {
        final CastContext ctx; Vec3d center; final double radius; final int tickRate; int duration;
        final boolean aura, toggle;
        Zone(CastContext ctx, Vec3d center, double radius, int duration, int tickRate, boolean aura, boolean toggle) {
            this.ctx = ctx; this.center = center; this.radius = radius;
            this.duration = duration; this.tickRate = Math.max(1, tickRate);
            this.aura = aura; this.toggle = toggle;
        }
    }
    private static final List<Zone> ACTIVE = new ArrayList<>();
    public static void start(CastContext ctx, FormDefinition form) {
        double radius = form.getDouble("radius", 5.0);
        int duration = form.getInt("duration", 100);
        int tickRate = form.getInt("tickRate", 10);
        Vec3d center = ctx.caster.getPos().add(0, 0.5, 0);
        boolean aura = ctx.hasProp("aura");
        boolean toggle = ctx.hasProp("toggle");
        ACTIVE.add(new Zone(ctx, center, radius, duration, tickRate, aura, toggle));
        Fx.elementBurst(ctx.world(), center, ctx.jutsu.getElement(), 30);
    }
    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Zone> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Zone z = it.next();
            LivingEntity caster = z.ctx.caster;
            if (!caster.isAlive()) { it.remove(); continue; }
            ServerWorld world = z.ctx.world();
            if (z.aura) z.center = caster.getPos().add(0, 0.5, 0);
            z.duration--;
            if (z.duration % z.tickRate == 0) {
                for (Object o : world.getOtherEntities(caster, new Box(z.center, z.center).expand(z.radius))) {
                    if (o instanceof LivingEntity e && e.isAlive() && !e.equals(caster)) EffectExecutor.applyEffects(z.ctx, e);
                }
                Fx.elementBurst(world, z.center, z.ctx.jutsu.getElement(), 5);
            }
            if (z.duration <= 0) it.remove();
        }
    }
    public static void toggleOff(UUID casterUuid) {
        ACTIVE.removeIf(z -> z.toggle && z.ctx.caster.getUuid().equals(casterUuid));
    }
}