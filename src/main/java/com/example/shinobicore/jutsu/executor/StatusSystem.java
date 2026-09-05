package com.example.shinobicore.jutsu.executor;

import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class StatusSystem {

    private static class Dot {
        final LivingEntity target;
        final double dps;
        int ticksLeft;
        final boolean cursed;
        Dot(LivingEntity t, double dps, int ticks, boolean cursed) {
            this.target = t; this.dps = dps; this.ticksLeft = ticks; this.cursed = cursed;
        }
    }

    private static class Vuln {
        final LivingEntity target;
        final double percent;
        int ticksLeft;
        Vuln(LivingEntity t, double p, int ticks) { target = t; percent = p; ticksLeft = ticks; }
    }

    private static final List<Dot> DOTS = new ArrayList<>();
    private static final List<Vuln> VULNS = new ArrayList<>();

    public static void addDot(LivingEntity target, double dps, int ticks) {
        DOTS.add(new Dot(target, dps, ticks, false));
    }

    public static void addCurse(LivingEntity target, double dps, int ticks) {
        DOTS.add(new Dot(target, dps, ticks, true));
    }

    public static void addVulnerability(LivingEntity target, double percent, int ticks) {
        VULNS.add(new Vuln(target, percent, ticks));
    }

    /** Damage multiplier from vulnerability (1.0 = no bonus). */
    public static double vulnerabilityMult(LivingEntity target) {
        double best = 0;
        for (Vuln v : VULNS) {
            if (v.target == target && v.ticksLeft > 0) best = Math.max(best, v.percent);
        }
        return 1.0 + best / 100.0;
    }

    /** Purify: remove non-cursed dots + negative status effects. */
    public static void purify(LivingEntity target) {
        DOTS.removeIf(d -> d.target == target && !d.cursed);
        for (net.minecraft.entity.effect.StatusEffectInstance inst : new ArrayList<>(target.getStatusEffects())) {
            var eff = inst.getEffectType();
            if (eff == net.minecraft.entity.effect.StatusEffects.SLOWNESS
                || eff == net.minecraft.entity.effect.StatusEffects.WEAKNESS
                || eff == net.minecraft.entity.effect.StatusEffects.POISON
                || eff == net.minecraft.entity.effect.StatusEffects.WITHER
                || eff == net.minecraft.entity.effect.StatusEffects.NAUSEA
                || eff == net.minecraft.entity.effect.StatusEffects.BLINDNESS
                || eff == net.minecraft.entity.effect.StatusEffects.MINING_FATIGUE) {
                target.removeStatusEffect(eff);
            }
        }
    }

    public static void tick(MinecraftServer server) {
        Iterator<Dot> di = DOTS.iterator();
        while (di.hasNext()) {
            Dot d = di.next();
            if (!d.target.isAlive()) { di.remove(); continue; }
            d.target.damage(d.target.getDamageSources().magic(), (float) (d.dps / 20.0));
            d.ticksLeft--;
            if (d.ticksLeft <= 0) di.remove();
        }
        Iterator<Vuln> vi = VULNS.iterator();
        while (vi.hasNext()) {
            Vuln v = vi.next();
            v.ticksLeft--;
            if (v.ticksLeft <= 0 || !v.target.isAlive()) vi.remove();
        }
    }
}