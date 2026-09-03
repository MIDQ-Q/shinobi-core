package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.FormDefinition;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class ZoneSystem {

    private static class Zone {
        final ServerWorld world;
        final Vec3d center;
        final JutsuDefinition jutsu;
        final double radius;
        final int tickRate;
        int duration;
        Zone(ServerWorld world, Vec3d center, JutsuDefinition jutsu, double radius, int duration, int tickRate) {
            this.world = world; this.center = center; this.jutsu = jutsu;
            this.radius = radius; this.duration = duration; this.tickRate = Math.max(1, tickRate);
        }
    }

    private static final List<Zone> ACTIVE = new ArrayList<>();

    public static void start(ServerPlayerEntity player, JutsuDefinition jutsu, FormDefinition form) {
        double radius = form.getDouble("radius", 5.0);
        int duration = form.getInt("duration", 100);
        int tickRate = form.getInt("tickRate", 10);
        Vec3d center = player.getPos().add(0, 0.5, 0);
        ACTIVE.add(new Zone(player.getServerWorld(), center, jutsu, radius, duration, tickRate));
        Fx.elementBurst(player.getServerWorld(), center, jutsu.getElement(), 30);
    }

    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Zone> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Zone z = it.next();
            z.duration--;
            if (z.duration % z.tickRate == 0) {
                for (Object o : z.world.getOtherEntities(null, new Box(z.center, z.center).expand(z.radius))) {
                    if (o instanceof LivingEntity e && e.isAlive()) {
                        // find caster? effects applied without caster reference
                        EffectExecutor.applyEffects(null, z.jutsu, e);
                    }
                }
                Fx.elementBurst(z.world, z.center, z.jutsu.getElement(), 5);
            }
            if (z.duration <= 0) it.remove();
        }
    }
}