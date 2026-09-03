package com.example.shinobicore.jutsu.executor;

import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class StatusSystem {

    private static class Dot {
        final LivingEntity target;
        final double dps;
        int ticksLeft;
        Dot(LivingEntity target, double dps, int ticks) {
            this.target = target; this.dps = dps; this.ticksLeft = ticks;
        }
    }

    private static final List<Dot> DOTS = new ArrayList<>();

    public static void addDot(LivingEntity target, double dps, int ticks) {
        DOTS.add(new Dot(target, dps, ticks));
    }

    public static void tick(MinecraftServer server) {
        if (DOTS.isEmpty()) return;
        Iterator<Dot> it = DOTS.iterator();
        while (it.hasNext()) {
            Dot d = it.next();
            if (!d.target.isAlive()) { it.remove(); continue; }
            d.target.damage(d.target.getDamageSources().magic(), (float) (d.dps / 20.0));
            d.ticksLeft--;
            if (d.ticksLeft <= 0) it.remove();
        }
    }
}