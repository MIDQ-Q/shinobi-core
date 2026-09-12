package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.VisualDefinition;
import com.example.shinobicore.jutsu.enums.ElementType;
import com.example.shinobicore.jutsu.executor.FxPalette.Settings;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

/**
 * FX v3 (ToolsPack 2 / 1.1.3) — серверный движок визуала техник.
 *
 * Новое относительно v2:
 *   - СТИЛИ эффектов из visual-блока JSON: trailStyle / impactStyle /
 *     castStyle / zoneStyle / beamStyle. Каждый стиль — готовая хореография
 *     частиц; неизвестный или отсутствующий стиль = "default" (поведение v2).
 *     Полный каталог: docs/formats/fx_styles.md и раздел FX Lab в Studio.
 *   - Новые эмиттеры-примитивы ( public, доступны из /shinobicore fx и любым
 *     будущим системам): lightPillar, vortex, helixColumn, shockwaveRing,
 *     chainArc, groundRunes, domeShell.
 *
 * Принципы (как в v2):
 *   - цвета/частицы — из FxPalette (стихия + visual JSON);
 *   - слоистость: ядро (dust) + стихия + glow-слой;
 *   - старые подписи сохранены — существующие вызовы не ломаются;
 *   - count=0 в spawnParticles — ванильный трюк: дельты = точная скорость
 *     одной частицы (направленные искры, имплозия, сбор чакры).
 */
public class Fx {

    // ======================================================================
    //  СТАРЫЙ API (v1/v2 — сохранён полностью)
    // ======================================================================

    public static void elementBurst(ServerWorld world, Vec3d pos, ElementType el, int count) {
        burst(world, pos, el, null, count);
    }

    public static void trail(ServerWorld world, Vec3d pos, ElementType el) {
        Settings s = FxPalette.of(el, null);
        world.spawnParticles(s.trail, pos.x, pos.y, pos.z, 2, 0.1, 0.1, 0.1, 0.01);
        world.spawnParticles(s.dust, pos.x, pos.y, pos.z, 1, 0.05, 0.05, 0.05, 0.0);
    }

    public static void spinningSphere(ServerWorld world, Vec3d center, ElementType el, double radius, int tick) {
        spinningSphere(world, center, el, null, radius, tick);
    }

    public static void impactRing(ServerWorld world, Vec3d center, ElementType el, double maxRadius, int tick, int duration) {
        Settings s = FxPalette.of(el, null);
        double progress = duration <= 0 ? 1.0 : Math.min(1.0, (double) tick / duration);
        double radius = Math.max(0.1, maxRadius * progress);
        int count = (int) (20 + progress * 20);
        for (int i = 0; i < count; i++) {
            double angle = (i / (double) count) * Math.PI * 2.0;
            double x = center.x + radius * Math.cos(angle);
            double y = center.y + 0.5 + (1.0 - progress) * 1.5;
            double z = center.z + radius * Math.sin(angle);
            ParticleEffect pe = (i % 3 == 0) ? s.dustGlow : s.main;
            world.spawnParticles(pe, x, y, z, 1, 0, 0.05, 0, 0.01);
        }
    }

    public static void burst(ServerWorld world, Vec3d pos, ElementType el, VisualDefinition vis, int count) {
        Settings s = FxPalette.of(el, vis);
        int n = Math.max(4, Math.min(64, (int) (count * Math.max(0.7, s.scale))));
        world.spawnParticles(s.main, pos.x, pos.y, pos.z, n, 0.4, 0.4, 0.4, 0.03);
        world.spawnParticles(s.dust, pos.x, pos.y, pos.z, Math.max(3, n / 3), 0.3, 0.3, 0.3, 0.02);
        if (n >= 12 || s.glow) {
            world.spawnParticles(ParticleTypes.END_ROD, pos.x, pos.y, pos.z, Math.max(2, n / 5), 0.25, 0.25, 0.25, 0.01);
        }
        if (el == ElementType.FIRE || (vis != null && "flame".equals(vis.getParticle()))) {
            world.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y, pos.z, n / 4, 0.3, 0.35, 0.3, 0.02);
        }
    }

    // ======================================================================
    //  ТРЕЙЛЫ (стили: default / ribbon / helix / smoke / sparks / lightning)
    // ======================================================================

    /** Совместимость с v2: трейл без направления движения. */
    public static void trailRich(ServerWorld world, Vec3d pos, ElementType el, VisualDefinition vis,
                                 double sizeScale, int tick) {
        trailRich(world, pos, null, el, vis, sizeScale, tick);
    }

    public static void trailRich(ServerWorld world, Vec3d pos, Vec3d motion, ElementType el,
                                 VisualDefinition vis, double sizeScale, int tick) {
        Settings s = FxPalette.of(el, vis);
        String style = styleOf(vis == null ? null : vis.getTrailStyle());
        switch (style) {
            case "ribbon" -> ribbonTrail(world, pos, motion, s, tick, sizeScale);
            case "helix" -> helixTrail(world, pos, motion, s, tick, sizeScale);
            case "smoke" -> smokeTrail(world, pos, s, tick);
            case "sparks" -> sparkTrail(world, pos, s, tick);
            case "lightning" -> lightningTrail(world, pos, s, tick);
            default -> coreTrail(world, pos, s, tick, sizeScale);
        }
    }

    private static void coreTrail(ServerWorld world, Vec3d pos, Settings s, int tick, double sizeScale) {
        double spread = 0.06 + 0.05 * Math.min(1.5, sizeScale);
        world.spawnParticles(s.dust, pos.x, pos.y, pos.z, 1, spread * 0.5, spread * 0.5, spread * 0.5, 0.0);
        world.spawnParticles(s.trail, pos.x, pos.y, pos.z, 2, spread, spread, spread, 0.01);
        if (s.glow && tick % 2 == 0) {
            world.spawnParticles(ParticleTypes.END_ROD, pos.x, pos.y, pos.z, 1, spread * 0.7, spread * 0.7, spread * 0.7, 0.0);
        }
        if (tick % 3 == 0) {
            world.spawnParticles(s.spark, pos.x, pos.y, pos.z, 1, spread, spread, spread, 0.02);
        }
    }

    private static void ribbonTrail(ServerWorld world, Vec3d pos, Vec3d motion, Settings s, int tick, double sizeScale) {
        if (motion == null || motion.lengthSquared() < 1e-9) { coreTrail(world, pos, s, tick, sizeScale); return; }
        Vec3d d = motion.normalize();
        Vec3d perp = Math.abs(d.y) < 0.9 ? d.crossProduct(new Vec3d(0, 1, 0)).normalize()
                                          : d.crossProduct(new Vec3d(1, 0, 0)).normalize();
        double w = 0.22 * Math.max(0.7, sizeScale);
        double ph = tick * 0.9;
        for (int k = -1; k <= 1; k += 2) {
            double off = Math.sin(ph) * w * k;
            Vec3d p = pos.add(perp.multiply(off)).add(0, Math.cos(ph) * w * 0.4 * k, 0);
            world.spawnParticles(s.dustGlow, p.x, p.y, p.z, 1, 0.02, 0.02, 0.02, 0.0);
            world.spawnParticles(s.trail, p.x, p.y, p.z, 1, 0.05, 0.05, 0.05, 0.01);
        }
        world.spawnParticles(s.dust, pos.x, pos.y, pos.z, 1, 0.04, 0.04, 0.04, 0.0);
        if (s.glow && tick % 3 == 0) {
            world.spawnParticles(ParticleTypes.END_ROD, pos.x, pos.y, pos.z, 1, 0.03, 0.03, 0.03, 0.0);
        }
    }

    private static void helixTrail(ServerWorld world, Vec3d pos, Vec3d motion, Settings s, int tick, double sizeScale) {
        if (motion == null || motion.lengthSquared() < 1e-9) { coreTrail(world, pos, s, tick, sizeScale); return; }
        Vec3d d = motion.normalize();
        Vec3d perp = Math.abs(d.y) < 0.9 ? d.crossProduct(new Vec3d(0, 1, 0)).normalize()
                                          : d.crossProduct(new Vec3d(1, 0, 0)).normalize();
        Vec3d up = d.crossProduct(perp).normalize();
        double r = 0.28 * Math.max(0.7, sizeScale);
        for (int k = 0; k < 2; k++) {
            double ph = tick * 0.8 + k * Math.PI;
            Vec3d p = pos.add(perp.multiply(Math.cos(ph) * r)).add(up.multiply(Math.sin(ph) * r));
            world.spawnParticles(k == 0 ? s.main : s.dustGlow, p.x, p.y, p.z, 1, 0.02, 0.02, 0.02, 0.0);
        }
        world.spawnParticles(s.dust, pos.x, pos.y, pos.z, 1, 0.03, 0.03, 0.03, 0.0);
    }

    private static void smokeTrail(ServerWorld world, Vec3d pos, Settings s, int tick) {
        world.spawnParticles(ParticleTypes.LARGE_SMOKE, pos.x, pos.y, pos.z, 1, 0.09, 0.09, 0.09, 0.005);
        world.spawnParticles(s.dust, pos.x, pos.y, pos.z, 1, 0.06, 0.06, 0.06, 0.0);
        if (tick % 2 == 0) {
            world.spawnParticles(s.main, pos.x, pos.y, pos.z, 1, 0.1, 0.1, 0.1, 0.02);
        }
        if (tick % 5 == 0) {
            world.spawnParticles(s.spark, pos.x, pos.y, pos.z, 2, 0.14, 0.14, 0.14, 0.05);
        }
    }

    private static void sparkTrail(ServerWorld world, Vec3d pos, Settings s, int tick) {
        world.spawnParticles(s.spark, pos.x, pos.y, pos.z, 3, 0.16, 0.16, 0.16, 0.12);
        world.spawnParticles(s.dust, pos.x, pos.y, pos.z, 1, 0.05, 0.05, 0.05, 0.0);
        if (s.glow && tick % 2 == 0) {
            world.spawnParticles(ParticleTypes.END_ROD, pos.x, pos.y, pos.z, 1, 0.06, 0.06, 0.06, 0.0);
        }
    }

    private static void lightningTrail(ServerWorld world, Vec3d pos, Settings s, int tick) {
        world.spawnParticles(s.dust, pos.x, pos.y, pos.z, 1, 0.03, 0.03, 0.03, 0.0);
        for (int i = 0; i < 2; i++) {
            double jx = (Math.random() - 0.5) * 0.35;
            double jy = (Math.random() - 0.5) * 0.35;
            double jz = (Math.random() - 0.5) * 0.35;
            world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, pos.x + jx, pos.y + jy, pos.z + jz,
                    1, 0.04, 0.04, 0.04, 0.08);
        }
        if (tick % 4 == 0) {
            world.spawnParticles(ParticleTypes.END_ROD, pos.x, pos.y, pos.z, 2, 0.1, 0.1, 0.1, 0.0);
        }
    }

    // ======================================================================
    //  КАСТ (стили круга: default / runes / pillars / spiral)
    // ======================================================================

    public static void castCircle(ServerWorld world, Vec3d feet, ElementType el, VisualDefinition vis,
                                  double radius, int tick) {
        Settings s = FxPalette.of(el, vis);
        String style = styleOf(vis == null ? null : vis.getCastStyle());
        double r = Math.max(0.5, radius * Math.max(0.7, s.scale));
        switch (style) {
            case "runes" -> castRunes(world, feet, s, r, tick);
            case "pillars" -> castPillars(world, feet, s, r, tick);
            case "spiral" -> castSpiral(world, feet, s, r, tick);
            default -> castDefault(world, feet, s, r, tick);
        }
    }

    private static void castDefault(ServerWorld world, Vec3d feet, Settings s, double r, int tick) {
        double y = feet.y + 0.08;
        int ringCount = 16;
        double a0 = tick * 0.12;
        for (int i = 0; i < ringCount; i++) {
            double a = a0 + i * Math.PI * 2.0 / ringCount;
            double x = feet.x + Math.cos(a) * r;
            double z = feet.z + Math.sin(a) * r;
            world.spawnParticles(s.main, x, y, z, 1, 0.02, 0.03, 0.02, 0.0);
            if (i % 2 == 0) world.spawnParticles(s.dust, x, y + 0.04, z, 1, 0.01, 0.01, 0.01, 0.0);
        }
        double r2 = r * 0.68;
        int inner = 10;
        double a1 = -tick * 0.2;
        for (int i = 0; i < inner; i++) {
            double a = a1 + i * Math.PI * 2.0 / inner;
            double x = feet.x + Math.cos(a) * r2;
            double z = feet.z + Math.sin(a) * r2;
            world.spawnParticles(s.dustGlow, x, y + 0.02, z, 1, 0.01, 0.02, 0.01, 0.0);
        }
        if (tick % 3 == 0) {
            for (int i = 0; i < 3; i++) {
                double a = Math.random() * Math.PI * 2.0;
                double x = feet.x + Math.cos(a) * r * 1.2;
                double z = feet.z + Math.sin(a) * r * 1.2;
                double vx = (feet.x - x) * 0.045;
                double vz = (feet.z - z) * 0.045;
                ParticleEffect pe = s.glow ? ParticleTypes.END_ROD : s.spark;
                world.spawnParticles(pe, x, y + 1.5, z, 0, vx, -0.07, vz, 0.0);
            }
        }
        if (tick % 20 == 0) {
            world.spawnParticles(ParticleTypes.END_ROD, feet.x, y + 0.15, feet.z, 5, 0.15, 0.08, 0.15, 0.0);
        }
    }

    private static void castRunes(ServerWorld world, Vec3d feet, Settings s, double r, int tick) {
        double y = feet.y + 0.08;
        // неподвижное внешнее кольцо + внутреннее
        for (int i = 0; i < 20; i++) {
            double a = i * Math.PI * 2.0 / 20;
            world.spawnParticles(s.dust, feet.x + Math.cos(a) * r, y, feet.z + Math.sin(a) * r, 1, 0.01, 0.01, 0.01, 0.0);
            if (i % 2 == 0) {
                world.spawnParticles(s.dustGlow, feet.x + Math.cos(a) * r * 0.72, y + 0.02,
                        feet.z + Math.sin(a) * r * 0.72, 1, 0.01, 0.01, 0.01, 0.0);
            }
        }
        // 4 «глифа» — плотные тройки точек, вращаются
        for (int g = 0; g < 4; g++) {
            double a = tick * 0.06 + g * Math.PI / 2.0;
            double gx = feet.x + Math.cos(a) * r * 0.86;
            double gz = feet.z + Math.sin(a) * r * 0.86;
            for (int k = 0; k < 3; k++) {
                double da = k * Math.PI * 2.0 / 3.0 + tick * 0.2;
                world.spawnParticles(s.glow ? ParticleTypes.END_ROD : s.spark,
                        gx + Math.cos(da) * 0.09, y + 0.06, gz + Math.sin(da) * 0.09, 1, 0, 0.01, 0, 0.0);
            }
        }
        if (tick % 4 == 0) {
            double a = Math.random() * Math.PI * 2.0;
            world.spawnParticles(s.main, feet.x + Math.cos(a) * r * 0.5, y + 0.1, feet.z + Math.sin(a) * r * 0.5,
                    1, 0.02, 0.06, 0.02, 0.0);
        }
        if (tick % 20 == 0) {
            world.spawnParticles(s.dustGlow, feet.x, y + 0.12, feet.z, 6, 0.12, 0.05, 0.12, 0.0);
        }
    }

    private static void castPillars(ServerWorld world, Vec3d feet, Settings s, double r, int tick) {
        double y = feet.y + 0.08;
        // 6 столбов по кругу, медленно вращаются
        for (int p = 0; p < 6; p++) {
            double a = tick * 0.04 + p * Math.PI / 3.0;
            double px = feet.x + Math.cos(a) * r;
            double pz = feet.z + Math.sin(a) * r;
            for (int h = 0; h < 4; h++) {
                double yy = y + 0.25 + h * 0.45 + Math.sin(tick * 0.15 + p + h) * 0.06;
                ParticleEffect pe = (h == 3) ? (s.glow ? ParticleTypes.END_ROD : s.spark) : s.main;
                world.spawnParticles(pe, px, yy, pz, 1, 0.02, 0.04, 0.02, 0.0);
            }
        }
        // базовое кольцо
        if (tick % 3 == 0) {
            for (int i = 0; i < 12; i++) {
                double a = -tick * 0.1 + i * Math.PI / 6.0;
                world.spawnParticles(s.dust, feet.x + Math.cos(a) * r * 0.92, y,
                        feet.z + Math.sin(a) * r * 0.92, 1, 0.01, 0.01, 0.01, 0.0);
            }
        }
        if (tick % 20 == 0) {
            world.spawnParticles(s.dustGlow, feet.x, y + 0.1, feet.z, 5, 0.2, 0.05, 0.2, 0.0);
        }
    }

    private static void castSpiral(ServerWorld world, Vec3d feet, Settings s, double r, int tick) {
        double y = feet.y + 0.08;
        // две спиральные руки, сходящиеся к центру
        for (int arm = 0; arm < 2; arm++) {
            for (int i = 0; i < 8; i++) {
                double t2 = ((tick * 3 + i * 8 + arm * 30) % 64) / 64.0;   // 0..1 к центру
                double rad = r * (1.15 - t2);
                double a = arm * Math.PI + t2 * 6.0 + tick * 0.05;
                double x = feet.x + Math.cos(a) * rad;
                double z = feet.z + Math.sin(a) * rad;
                ParticleEffect pe = (i % 3 == 0) ? s.dustGlow : s.main;
                world.spawnParticles(pe, x, y + t2 * 0.5, z, 1, 0.02, 0.02, 0.02, 0.0);
            }
        }
        if (tick % 10 == 0) {
            world.spawnParticles(s.glow ? ParticleTypes.END_ROD : s.spark, feet.x, y + 0.15, feet.z,
                    3, 0.08, 0.1, 0.08, 0.0);
        }
    }

    /** Сбор чакры в руку при зарядке (v2, без изменений). */
    public static void chargeGather(ServerWorld world, Vec3d hand, ElementType el, VisualDefinition vis, int tick) {
        Settings s = FxPalette.of(el, vis);
        int streams = 4;
        for (int i = 0; i < streams; i++) {
            double a = (tick * 0.35) + i * Math.PI * 2.0 / streams + Math.random() * 0.4;
            double yy = 0.85 + Math.random() * 0.7;
            double rad = 1.05 + Math.random() * 0.25;
            double x = hand.x + Math.cos(a) * rad;
            double y = hand.y + yy - 0.6;
            double z = hand.z + Math.sin(a) * rad;
            double vx = (hand.x - x) * 0.09;
            double vy = (hand.y - y) * 0.09;
            double vz = (hand.z - z) * 0.09;
            ParticleEffect pe = (i % 2 == 0) ? s.dust : s.main;
            world.spawnParticles(pe, x, y, z, 0, vx, vy, vz, 0.0);
        }
        if (tick % 5 == 0) {
            world.spawnParticles(ParticleTypes.END_ROD, hand.x, hand.y, hand.z, 2, 0.08, 0.08, 0.08, 0.0);
        }
    }

    // ======================================================================
    //  ЛУЧ (стили: default / lightning / spiral / pulse)
    // ======================================================================

    public static void beamCore(ServerWorld world, Vec3d start, Vec3d dir, double length, double width,
                                ElementType el, VisualDefinition vis, int tick) {
        Settings s = FxPalette.of(el, vis);
        Vec3d d = dir != null && dir.lengthSquared() > 1e-9 ? dir.normalize() : new Vec3d(0, 0, 1);
        String style = styleOf(vis == null ? null : vis.getBeamStyle());
        switch (style) {
            case "lightning" -> beamLightning(world, start, d, length, width, s, tick);
            case "spiral" -> beamSpiral(world, start, d, length, width, s, tick);
            case "pulse" -> beamPulse(world, start, d, length, width, s, tick);
            default -> beamDefault(world, start, d, length, width, s, tick);
        }
    }

    private static Vec3d beamPerp(Vec3d d) {
        return Math.abs(d.y) < 0.9 ? d.crossProduct(new Vec3d(0, 1, 0)).normalize()
                                   : d.crossProduct(new Vec3d(1, 0, 0)).normalize();
    }

    private static void beamDefault(ServerWorld world, Vec3d start, Vec3d d, double length, double width,
                                    Settings s, int tick) {
        Vec3d perp = beamPerp(d);
        double w = Math.max(0.25, width * 0.5 * Math.max(0.7, s.scale));
        double step = 0.75;
        int steps = (int) Math.max(2, length / step);
        for (int i = 0; i <= steps; i++) {
            double dist = i * step;
            Vec3d p = start.add(d.multiply(dist));
            world.spawnParticles(s.dust, p.x, p.y, p.z, 1, w * 0.25, w * 0.25, w * 0.25, 0.0);
            if (i % 2 == 0) {
                double off = ((tick * 37L + i * 61L) % 100) / 100.0 * 2.0 - 1.0;
                Vec3d side = p.add(perp.multiply(off * w));
                world.spawnParticles(s.main, side.x, side.y, side.z, 1, w * 0.35, w * 0.35, w * 0.35, 0.01);
            }
            if (s.glow && i % 3 == 0) {
                world.spawnParticles(ParticleTypes.END_ROD, p.x, p.y, p.z, 1, w * 0.15, w * 0.15, w * 0.15, 0.0);
            }
        }
        double pulseDist = (tick * 1.6) % Math.max(1.0, length);
        Vec3d pulse = start.add(d.multiply(pulseDist));
        world.spawnParticles(s.dustGlow, pulse.x, pulse.y, pulse.z, 3, w * 0.4, w * 0.4, w * 0.4, 0.0);
    }

    private static void beamLightning(ServerWorld world, Vec3d start, Vec3d d, double length, double width,
                                      Settings s, int tick) {
        Vec3d perp = beamPerp(d);
        Vec3d up = d.crossProduct(perp).normalize();
        // ломаная обновляется каждые 4 тика — «мерцание» разряда
        long seed = tick / 4;
        double seg = Math.max(0.9, length / 9.0);
        int segs = (int) Math.ceil(length / seg);
        double offP = 0, offU = 0;
        Vec3d prev = start;
        java.util.Random rnd = new java.util.Random(seed * 31 + 7);
        for (int i = 1; i <= segs; i++) {
            double dist = Math.min(length, i * seg);
            offP = (rnd.nextDouble() - 0.5) * width * 1.3;
            offU = (rnd.nextDouble() - 0.5) * width * 1.3;
            Vec3d cur = start.add(d.multiply(dist)).add(perp.multiply(offP)).add(up.multiply(offU));
            int sub = 3;
            for (int k = 0; k <= sub; k++) {
                Vec3d p = prev.add(cur.subtract(prev).multiply(k / (double) sub));
                world.spawnParticles(s.dust, p.x, p.y, p.z, 1, 0.03, 0.03, 0.03, 0.0);
                if (k % 2 == 0) {
                    world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, p.x, p.y, p.z, 1, 0.08, 0.08, 0.08, 0.05);
                }
            }
            prev = cur;
        }
        if (tick % 4 == 0) {
            world.spawnParticles(ParticleTypes.END_ROD, start.x, start.y, start.z, 3, 0.1, 0.1, 0.1, 0.0);
            Vec3d endP = start.add(d.multiply(length));
            world.spawnParticles(s.spark, endP.x, endP.y, endP.z, 4, 0.25, 0.25, 0.25, 0.1);
        }
    }

    private static void beamSpiral(ServerWorld world, Vec3d start, Vec3d d, double length, double width,
                                   Settings s, int tick) {
        Vec3d perp = beamPerp(d);
        Vec3d up = d.crossProduct(perp).normalize();
        double w = Math.max(0.2, width * 0.45);
        double step = 0.55;
        int steps = (int) Math.max(2, length / step);
        for (int i = 0; i <= steps; i++) {
            double dist = i * step;
            double a = dist * 2.2 + tick * 0.45;
            Vec3d base = start.add(d.multiply(dist));
            for (int strand = 0; strand < 2; strand++) {
                double aa = a + strand * Math.PI;
                Vec3d p = base.add(perp.multiply(Math.cos(aa) * w)).add(up.multiply(Math.sin(aa) * w));
                ParticleEffect pe = strand == 0 ? s.main : s.dustGlow;
                world.spawnParticles(pe, p.x, p.y, p.z, 1, 0.02, 0.02, 0.02, 0.0);
            }
            if (i % 3 == 0) {
                world.spawnParticles(s.dust, base.x, base.y, base.z, 1, 0.04, 0.04, 0.04, 0.0);
            }
        }
    }

    private static void beamPulse(ServerWorld world, Vec3d start, Vec3d d, double length, double width,
                                  Settings s, int tick) {
        double w = Math.max(0.2, width * 0.3);
        // тонкое ядро
        double step = 1.1;
        int steps = (int) Math.max(2, length / step);
        for (int i = 0; i <= steps; i++) {
            Vec3d p = start.add(d.multiply(i * step));
            world.spawnParticles(s.dust, p.x, p.y, p.z, 1, w * 0.2, w * 0.2, w * 0.2, 0.0);
        }
        // плотные сгустки, бегущие к концу
        for (int b = 0; b < 2; b++) {
            double dist = ((tick * 2.4) + b * length * 0.5) % Math.max(1.0, length);
            Vec3d p = start.add(d.multiply(dist));
            world.spawnParticles(s.dustGlow, p.x, p.y, p.z, 4, w * 0.55, w * 0.55, w * 0.55, 0.0);
            world.spawnParticles(s.glow ? ParticleTypes.END_ROD : s.main, p.x, p.y, p.z, 2, w * 0.4, w * 0.4, w * 0.4, 0.01);
        }
    }

    // ======================================================================
    //  ЗОНА (стили: default / dome / rune_circle / vortex / wall)
    // ======================================================================

    public static void zoneVisual(ServerWorld world, Vec3d center, double radius,
                                  ElementType el, VisualDefinition vis, int tick) {
        Settings s = FxPalette.of(el, vis);
        String style = styleOf(vis == null ? null : vis.getZoneStyle());
        double r = Math.max(0.8, radius);
        switch (style) {
            case "dome" -> zoneDome(world, center, s, r, tick);
            case "rune_circle" -> zoneRuneCircle(world, center, s, r, tick);
            case "vortex" -> zoneVortex(world, center, s, r, tick);
            case "wall" -> zoneWall(world, center, s, r, tick);
            default -> zoneDefault(world, center, s, r, tick);
        }
    }

    private static void zoneDefault(ServerWorld world, Vec3d center, Settings s, double r, int tick) {
        double y = center.y - 0.35;
        int ringCount = Math.max(12, Math.min(48, (int) (r * 6)));
        double a0 = tick * 0.05;
        for (int i = 0; i < ringCount; i++) {
            double a = a0 + i * Math.PI * 2.0 / ringCount;
            double x = center.x + Math.cos(a) * r;
            double z = center.z + Math.sin(a) * r;
            ParticleEffect pe = (i % 4 == 0) ? s.dustGlow : s.dust;
            world.spawnParticles(pe, x, y + 0.12, z, 1, 0.03, 0.06, 0.03, 0.0);
        }
        if (tick % 2 == 0) {
            int inner = Math.max(8, ringCount / 2);
            double a1 = -tick * 0.08;
            double r2 = r * 0.92;
            for (int i = 0; i < inner; i++) {
                double a = a1 + i * Math.PI * 2.0 / inner;
                world.spawnParticles(s.main, center.x + Math.cos(a) * r2, y + 0.08,
                        center.z + Math.sin(a) * r2, 1, 0.03, 0.03, 0.03, 0.0);
            }
        }
        if (tick % 4 == 0) {
            for (int k = 0; k < 4; k++) {
                double a = tick * 0.01 + k * Math.PI / 2.0;
                double x = center.x + Math.cos(a) * r;
                double z = center.z + Math.sin(a) * r;
                for (int h = 0; h < 3; h++) {
                    world.spawnParticles(s.glow ? ParticleTypes.END_ROD : s.spark,
                            x, y + 0.25 + h * 0.45, z, 1, 0.02, 0.05, 0.02, 0.0);
                }
            }
        }
        if (tick % 6 == 0) {
            for (int i = 0; i < 3; i++) {
                double a = Math.random() * Math.PI * 2.0;
                double rr = Math.sqrt(Math.random()) * r * 0.85;
                world.spawnParticles(s.trail, center.x + Math.cos(a) * rr, y + 0.1,
                        center.z + Math.sin(a) * rr, 1, 0.08, 0.05, 0.08, 0.0);
            }
        }
    }

    private static void zoneDome(ServerWorld world, Vec3d center, Settings s, double r, int tick) {
        double y = center.y - 0.35;
        // полусфера из мерцающих точек (фибоначчи-распределение, верхняя половина)
        int n = 26;
        double golden = Math.PI * (3.0 - Math.sqrt(5.0));
        for (int i = 0; i < n; i++) {
            double yy = (i / (double) (n - 1));             // 0..1
            double rad = Math.sqrt(Math.max(0, 1.0 - yy * yy));
            double a = i * golden + tick * 0.03;
            double x = center.x + Math.cos(a) * rad * r;
            double z = center.z + Math.sin(a) * rad * r;
            double py = y + yy * r;
            boolean bright = (tick + i) % 7 < 2;
            ParticleEffect pe = bright ? (s.glow ? ParticleTypes.END_ROD : s.dustGlow) : s.dust;
            world.spawnParticles(pe, x, py, z, 1, 0.01, 0.01, 0.01, 0.0);
        }
        // кольцо основания
        if (tick % 2 == 0) {
            for (int i = 0; i < 16; i++) {
                double a = tick * 0.05 + i * Math.PI / 8.0;
                world.spawnParticles(s.main, center.x + Math.cos(a) * r, y + 0.1,
                        center.z + Math.sin(a) * r, 1, 0.03, 0.03, 0.03, 0.0);
            }
        }
    }

    private static void zoneRuneCircle(ServerWorld world, Vec3d center, Settings s, double r, int tick) {
        double y = center.y - 0.3;
        // два встречных кольца
        int n = Math.max(14, Math.min(40, (int) (r * 5)));
        for (int i = 0; i < n; i++) {
            double a1 = tick * 0.045 + i * Math.PI * 2.0 / n;
            double a2 = -tick * 0.06 + i * Math.PI * 2.0 / n;
            world.spawnParticles(s.dust, center.x + Math.cos(a1) * r, y + 0.1,
                    center.z + Math.sin(a1) * r, 1, 0.01, 0.02, 0.01, 0.0);
            world.spawnParticles(s.dustGlow, center.x + Math.cos(a2) * r * 0.82, y + 0.14,
                    center.z + Math.sin(a2) * r * 0.82, 1, 0.01, 0.02, 0.01, 0.0);
        }
        // 8 вращающихся спиц
        if (tick % 3 == 0) {
            for (int k = 0; k < 8; k++) {
                double a = tick * 0.02 + k * Math.PI / 4.0;
                double rr = r * (0.25 + ((tick + k * 5) % 20) / 20.0 * 0.7);
                world.spawnParticles(s.main, center.x + Math.cos(a) * rr, y + 0.12,
                        center.z + Math.sin(a) * rr, 1, 0.02, 0.03, 0.02, 0.0);
            }
        }
        // пульс центра
        if (tick % 20 < 3) {
            world.spawnParticles(s.glow ? ParticleTypes.END_ROD : s.spark, center.x, y + 0.2, center.z,
                    4, 0.15, 0.1, 0.15, 0.0);
        }
    }

    private static void zoneVortex(ServerWorld world, Vec3d center, Settings s, double r, int tick) {
        double y = center.y - 0.35;
        // восходящая воронка: радиус сужается кверху
        int strands = 12;
        for (int i = 0; i < strands; i++) {
            double life = ((tick * 3 + i * 11) % 40) / 40.0;      // 0 низ -> 1 верх
            double a = tick * 0.12 + i * Math.PI * 2.0 / strands + life * 3.5;
            double rad = r * (1.0 - life * 0.65);
            double x = center.x + Math.cos(a) * rad;
            double z = center.z + Math.sin(a) * rad;
            ParticleEffect pe = life > 0.75 ? s.dustGlow : s.main;
            world.spawnParticles(pe, x, y + life * 2.6, z, 1, 0.03, 0.05, 0.03, 0.01);
        }
        // редкая граница
        if (tick % 4 == 0) {
            for (int i = 0; i < 8; i++) {
                double a = -tick * 0.05 + i * Math.PI / 4.0;
                world.spawnParticles(s.dust, center.x + Math.cos(a) * r, y + 0.1,
                        center.z + Math.sin(a) * r, 1, 0.02, 0.02, 0.02, 0.0);
            }
        }
    }

    private static void zoneWall(ServerWorld world, Vec3d center, Settings s, double r, int tick) {
        double y = center.y - 0.35;
        int n = Math.max(16, Math.min(48, (int) (r * 5)));
        // «занавес»: частицы поднимаются по границе
        for (int i = 0; i < n; i++) {
            double a = i * Math.PI * 2.0 / n + tick * 0.01;
            double rise = ((tick * 4 + i * 13) % 44) / 44.0;      // 0..1 вверх
            double x = center.x + Math.cos(a) * r;
            double z = center.z + Math.sin(a) * r;
            ParticleEffect pe = rise > 0.8 ? s.dustGlow : (rise < 0.15 ? s.dust : s.main);
            world.spawnParticles(pe, x, y + rise * 2.2, z, 1, 0.02, 0.02, 0.02, 0.0);
        }
        // верхнее и нижнее кольца
        if (tick % 3 == 0) {
            for (int i = 0; i < 12; i++) {
                double a = tick * 0.04 + i * Math.PI / 6.0;
                world.spawnParticles(s.dust, center.x + Math.cos(a) * r, y + 2.2,
                        center.z + Math.sin(a) * r, 1, 0.02, 0.02, 0.02, 0.0);
            }
        }
    }

    // ======================================================================
    //  ВСПЫШКА ПОПАДАНИЯ (стили: default / nova / shockwave / implosion)
    // ======================================================================

    public static void impactFlash(ServerWorld world, Vec3d pos, ElementType el, VisualDefinition vis, double power) {
        Settings s = FxPalette.of(el, vis);
        String style = styleOf(vis == null ? null : vis.getImpactStyle());
        double pw = Math.max(0.5, Math.min(6.0, power));
        switch (style) {
            case "nova" -> impactNova(world, pos, s, pw);
            case "shockwave" -> impactShockwave(world, pos, s, pw);
            case "implosion" -> impactImplosion(world, pos, s, pw);
            default -> impactDefault(world, pos, s, pw);
        }
    }

    private static void impactDefault(ServerWorld world, Vec3d pos, Settings s, double pw) {
        world.spawnParticles(ParticleTypes.END_ROD, pos.x, pos.y + 0.3, pos.z,
                (int) (5 + pw * 2), 0.2 * pw, 0.2 * pw, 0.2 * pw, 0.01);
        int ring = (int) (14 + pw * 5);
        for (int i = 0; i < ring; i++) {
            double a = i * Math.PI * 2.0 / ring;
            double x = pos.x + Math.cos(a) * pw * 0.6;
            double z = pos.z + Math.sin(a) * pw * 0.6;
            double vx = Math.cos(a) * 0.16;
            double vz = Math.sin(a) * 0.16;
            world.spawnParticles(s.main, x, pos.y + 0.35, z, 0, vx, 0.05, vz, 0.0);
            if (i % 3 == 0) world.spawnParticles(s.dustGlow, x, pos.y + 0.35, z, 1, 0.05, 0.05, 0.05, 0.0);
        }
        world.spawnParticles(s.spark, pos.x, pos.y + 0.4, pos.z, (int) (6 + pw * 2), 0.35, 0.35, 0.35, 0.08);
        world.spawnParticles(s.dust, pos.x, pos.y + 0.3, pos.z, (int) (6 + pw * 2), 0.3 * pw, 0.25 * pw, 0.3 * pw, 0.02);
        if (pw >= 1.5) {
            world.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y + 0.5, pos.z, (int) (pw * 2), 0.3, 0.4, 0.3, 0.02);
        }
    }

    private static void impactNova(ServerWorld world, Vec3d pos, Settings s, double pw) {
        impactDefault(world, pos, s, pw);
        // столб света вверх
        double h = 1.2 + pw * 0.9;
        for (int i = 0; i < 8; i++) {
            double yy = pos.y + 0.3 + (i / 8.0) * h;
            world.spawnParticles(s.glow ? ParticleTypes.END_ROD : s.dustGlow, pos.x, yy, pos.z,
                    2, 0.08, 0.12, 0.08, 0.0);
        }
        // второе широкое кольцо
        int n = (int) (18 + pw * 6);
        for (int i = 0; i < n; i++) {
            double a = i * Math.PI * 2.0 / n;
            double x = pos.x + Math.cos(a) * pw * 1.15;
            double z = pos.z + Math.sin(a) * pw * 1.15;
            world.spawnParticles(s.main, x, pos.y + 0.25, z, 0,
                    Math.cos(a) * 0.24, 0.02, Math.sin(a) * 0.24, 0.0);
        }
    }

    private static void impactShockwave(ServerWorld world, Vec3d pos, Settings s, double pw) {
        // плоское плотное кольцо, быстро летящее наружу
        int n = (int) (24 + pw * 8);
        for (int i = 0; i < n; i++) {
            double a = i * Math.PI * 2.0 / n;
            double x = pos.x + Math.cos(a) * pw * 0.35;
            double z = pos.z + Math.sin(a) * pw * 0.35;
            world.spawnParticles(s.dust, x, pos.y + 0.12, z, 0,
                    Math.cos(a) * 0.42, 0.005, Math.sin(a) * 0.42, 0.0);
            if (i % 2 == 0) {
                world.spawnParticles(s.main, x, pos.y + 0.18, z, 0,
                        Math.cos(a) * 0.3, 0.02, Math.sin(a) * 0.3, 0.0);
            }
        }
        world.spawnParticles(ParticleTypes.END_ROD, pos.x, pos.y + 0.25, pos.z, 6, 0.15, 0.1, 0.15, 0.01);
        world.spawnParticles(ParticleTypes.SMOKE, pos.x, pos.y + 0.15, pos.z, (int) (3 + pw), 0.4, 0.1, 0.4, 0.02);
    }

    private static void impactImplosion(ServerWorld world, Vec3d pos, Settings s, double pw) {
        // частицы летят ИЗ окружения В точку
        int n = 18;
        for (int i = 0; i < n; i++) {
            double a = i * Math.PI * 2.0 / n;
            double rad = pw * 1.6;
            double x = pos.x + Math.cos(a) * rad;
            double z = pos.z + Math.sin(a) * rad;
            double y = pos.y + 0.2 + (i % 3) * 0.45;
            world.spawnParticles(i % 3 == 0 ? s.dustGlow : s.main, x, y, z, 0,
                    (pos.x - x) * 0.16, (pos.y + 0.3 - y) * 0.1, (pos.z - z) * 0.16, 0.0);
        }
        world.spawnParticles(ParticleTypes.END_ROD, pos.x, pos.y + 0.3, pos.z, (int) (4 + pw * 2), 0.12, 0.12, 0.12, 0.0);
        world.spawnParticles(s.spark, pos.x, pos.y + 0.3, pos.z, 8, 0.12, 0.12, 0.12, 0.02);
    }

    public static void muzzleFlash(ServerWorld world, Vec3d pos, Vec3d dir, ElementType el, VisualDefinition vis) {
        Settings s = FxPalette.of(el, vis);
        Vec3d d = dir != null && dir.lengthSquared() > 1e-9 ? dir.normalize() : Vec3d.ZERO;
        world.spawnParticles(s.main, pos.x, pos.y, pos.z, 6,
                0.12 + d.x * 0.2, 0.12 + d.y * 0.2, 0.12 + d.z * 0.2, 0.06);
        world.spawnParticles(s.dustGlow, pos.x, pos.y, pos.z, 3, 0.08, 0.08, 0.08, 0.0);
        if (s.glow) {
            world.spawnParticles(ParticleTypes.END_ROD, pos.x + d.x * 0.2, pos.y + d.y * 0.2,
                    pos.z + d.z * 0.2, 2, 0.05, 0.05, 0.05, 0.0);
        }
    }

    public static void dashGhost(ServerWorld world, Vec3d body, ElementType el, VisualDefinition vis, int tick) {
        Settings s = FxPalette.of(el, vis);
        double r = 0.55 * Math.max(0.8, s.scale);
        for (int i = 0; i < 8; i++) {
            double a = tick * 0.5 + i * Math.PI / 4.0;
            double x = body.x + Math.cos(a) * r;
            double z = body.z + Math.sin(a) * r;
            world.spawnParticles(s.dust, x, body.y - 0.4 + (i % 3) * 0.45, z, 1, 0.03, 0.05, 0.03, 0.0);
        }
        if (tick % 2 == 0) {
            world.spawnParticles(s.main, body.x, body.y - 0.2, body.z, 2, 0.25, 0.15, 0.25, 0.02);
        }
        if (s.glow && tick % 3 == 0) {
            world.spawnParticles(ParticleTypes.END_ROD, body.x, body.y, body.z, 1, 0.2, 0.3, 0.2, 0.01);
        }
    }

    public static void fuseSpark(ServerWorld world, Vec3d pos, ElementType el, VisualDefinition vis, int ticksLeft) {
        Settings s = FxPalette.of(el, vis);
        int heat = ticksLeft <= 8 ? 3 : (ticksLeft <= 16 ? 2 : 1);
        world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, pos.x, pos.y + 0.15, pos.z,
                heat, 0.15, 0.1, 0.15, 0.03);
        world.spawnParticles(s.dust, pos.x, pos.y + 0.1, pos.z, heat, 0.1, 0.05, 0.1, 0.0);
        if (heat >= 2 && ticksLeft % 2 == 0) {
            world.spawnParticles(s.main, pos.x, pos.y + 0.2, pos.z, 1, 0.08, 0.12, 0.08, 0.01);
        }
    }

    public static void spinningSphere(ServerWorld world, Vec3d center, ElementType el, VisualDefinition vis,
                                      double radius, int tick) {
        Settings s = FxPalette.of(el, vis);
        double baseAngle = tick * 0.4;
        double r = Math.max(0.15, radius * Math.max(0.6, s.scale));
        for (int ring = 0; ring < 3; ring++) {
            double phi = ring * Math.PI / 3.0;
            for (int i = 0; i < 8; i++) {
                double angle = baseAngle + (i / 8.0) * Math.PI * 2.0;
                double x = center.x + r * Math.cos(angle) * Math.cos(phi);
                double y = center.y + r * Math.sin(angle);
                double z = center.z + r * Math.cos(angle) * Math.sin(phi);
                ParticleEffect pe = (i % 2 == 0) ? s.main : s.dustGlow;
                world.spawnParticles(pe, x, y, z, 1, 0, 0, 0, 0);
            }
        }
        world.spawnParticles(s.dust, center.x, center.y, center.z, 3, r * 0.25, r * 0.25, r * 0.25, 0.0);
        world.spawnParticles(ParticleTypes.END_ROD, center.x, center.y, center.z, 2, 0.1 * r, 0.1 * r, 0.1 * r, 0.0);
        if (s.glow && tick % 4 == 0) {
            world.spawnParticles(s.spark, center.x, center.y, center.z, 2, r * 0.5, r * 0.5, r * 0.5, 0.04);
        }
    }

    // ======================================================================
    //  НОВЫЕ ЭМИТТЕРЫ-ПРИМИТИВЫ (ToolsPack 2)
    // ======================================================================

    /** Столп света: восходящий поток + базовое кольцо + искры наверху. */
    public static void lightPillar(ServerWorld world, Vec3d base, ElementType el, VisualDefinition vis,
                                   double height, int tick) {
        Settings s = FxPalette.of(el, vis);
        double h = Math.max(1.0, height);
        for (int i = 0; i < 7; i++) {
            double yy = base.y + ((tick * 0.14 + i * 0.19) % 1.0) * h;
            double rad = 0.22 + 0.1 * Math.sin(tick * 0.2 + i);
            double a = tick * 0.3 + i * 1.7;
            ParticleEffect pe = (i % 3 == 0) ? (s.glow ? ParticleTypes.END_ROD : s.dustGlow) : s.dust;
            world.spawnParticles(pe, base.x + Math.cos(a) * rad, yy, base.z + Math.sin(a) * rad,
                    1, 0.02, 0.06, 0.02, 0.0);
        }
        if (tick % 3 == 0) {
            for (int i = 0; i < 8; i++) {
                double a = tick * 0.08 + i * Math.PI / 4.0;
                world.spawnParticles(s.main, base.x + Math.cos(a) * 0.55, base.y + 0.08,
                        base.z + Math.sin(a) * 0.55, 1, 0.03, 0.04, 0.03, 0.0);
            }
        }
        if (tick % 6 == 0) {
            world.spawnParticles(s.spark, base.x, base.y + h, base.z, 2, 0.2, 0.1, 0.2, 0.03);
        }
    }

    /** Воронка/торнадо: восходящие спирали + пылевое основание. */
    public static void vortex(ServerWorld world, Vec3d base, ElementType el, VisualDefinition vis,
                              double radius, double height, int tick) {
        Settings s = FxPalette.of(el, vis);
        double r = Math.max(0.4, radius);
        double h = Math.max(1.0, height);
        int strands = 10;
        for (int i = 0; i < strands; i++) {
            double life = ((tick * 4 + i * 9) % 44) / 44.0;
            double a = tick * 0.22 + i * Math.PI * 2.0 / strands + life * 4.5;
            double rad = r * (1.0 - life * 0.7);
            ParticleEffect pe = life > 0.7 ? s.dustGlow : (life > 0.35 ? s.main : s.trail);
            world.spawnParticles(pe, base.x + Math.cos(a) * rad, base.y + life * h,
                    base.z + Math.sin(a) * rad, 1, 0.04, 0.05, 0.04, 0.01);
        }
        if (tick % 3 == 0) {
            for (int i = 0; i < 6; i++) {
                double a = -tick * 0.1 + i * Math.PI / 3.0;
                world.spawnParticles(s.dust, base.x + Math.cos(a) * r * 1.1, base.y + 0.06,
                        base.z + Math.sin(a) * r * 1.1, 1, 0.05, 0.02, 0.05, 0.0);
            }
        }
    }

    /** Двойная восходящая спираль (ДНК) вокруг вертикальной оси. */
    public static void helixColumn(ServerWorld world, Vec3d base, ElementType el, VisualDefinition vis,
                                   double height, double radius, int tick) {
        Settings s = FxPalette.of(el, vis);
        double h = Math.max(0.5, height);
        double r = Math.max(0.2, radius);
        for (int strand = 0; strand < 2; strand++) {
            for (int i = 0; i < 7; i++) {
                double t2 = ((tick * 0.05 + i / 7.0) % 1.0);
                double a = t2 * Math.PI * 4.0 + strand * Math.PI;
                double x = base.x + Math.cos(a) * r;
                double z = base.z + Math.sin(a) * r;
                ParticleEffect pe = strand == 0 ? s.main : s.dustGlow;
                world.spawnParticles(pe, x, base.y + t2 * h, z, 1, 0.02, 0.02, 0.02, 0.0);
            }
        }
        if (tick % 4 == 0) {
            world.spawnParticles(s.dust, base.x, base.y + h * 0.5, base.z, 2, 0.08, 0.2, 0.08, 0.0);
        }
    }

    /**
     * Расширяющееся ударное кольцо, живущее duration тиков.
     * Вызывать КАЖДЫЙ тик с растущим age (0..duration) — например из
     * серверного тика системы или из /shinobicore fx.
     */
    public static void shockwaveRing(ServerWorld world, Vec3d pos, ElementType el, VisualDefinition vis,
                                     double maxRadius, int age, int duration) {
        Settings s = FxPalette.of(el, vis);
        if (age < 0 || duration <= 0 || age > duration) return;
        double t2 = age / (double) duration;
        double r = Math.max(0.1, maxRadius * t2);
        int n = (int) (20 + t2 * 16);
        for (int i = 0; i < n; i++) {
            double a = i * Math.PI * 2.0 / n;
            double x = pos.x + Math.cos(a) * r;
            double z = pos.z + Math.sin(a) * r;
            ParticleEffect pe = (i % 3 == 0) ? s.dustGlow : s.main;
            world.spawnParticles(pe, x, pos.y + 0.15 + (1.0 - t2) * 0.35, z, 1,
                    0.04, 0.03, 0.04, 0.01);
        }
        if (age == 0) {
            world.spawnParticles(ParticleTypes.END_ROD, pos.x, pos.y + 0.3, pos.z, 8, 0.2, 0.15, 0.2, 0.01);
        }
    }

    /** Зубчатая дуга молнии/чакры между двумя точками (для chaining и связок). */
    public static void chainArc(ServerWorld world, Vec3d from, Vec3d to, ElementType el,
                                VisualDefinition vis, int tick) {
        Settings s = FxPalette.of(el, vis);
        Vec3d delta = to.subtract(from);
        int segs = 8;
        long seed = tick / 3;
        java.util.Random rnd = new java.util.Random(seed * 17 + 3);
        Vec3d prev = from;
        for (int i = 1; i <= segs; i++) {
            Vec3d cur = from.add(delta.multiply(i / (double) segs));
            if (i < segs) {
                cur = cur.add((rnd.nextDouble() - 0.5) * 0.45,
                              (rnd.nextDouble() - 0.5) * 0.45,
                              (rnd.nextDouble() - 0.5) * 0.45);
            }
            int sub = 2;
            for (int k = 0; k <= sub; k++) {
                Vec3d p = prev.add(cur.subtract(prev).multiply(k / (double) sub));
                world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, p.x, p.y, p.z, 1, 0.03, 0.03, 0.03, 0.04);
                if (k == 0) world.spawnParticles(s.dust, p.x, p.y, p.z, 1, 0.02, 0.02, 0.02, 0.0);
            }
            prev = cur;
        }
        if (tick % 3 == 0) {
            world.spawnParticles(s.glow ? ParticleTypes.END_ROD : s.spark, to.x, to.y, to.z, 3, 0.12, 0.12, 0.12, 0.02);
        }
    }

    /** Рунный круг на земле: 3 концентрических кольца + вращающиеся глифы. */
    public static void groundRunes(ServerWorld world, Vec3d pos, ElementType el, VisualDefinition vis,
                                   double radius, int tick) {
        Settings s = FxPalette.of(el, vis);
        double y = pos.y + 0.06;
        double r = Math.max(0.6, radius);
        for (int ring = 0; ring < 3; ring++) {
            double rr = r * (1.0 - ring * 0.28);
            int n = 14 + ring * 4;
            double dir = (ring % 2 == 0) ? 1 : -1;
            for (int i = 0; i < n; i++) {
                double a = dir * tick * (0.03 + ring * 0.015) + i * Math.PI * 2.0 / n;
                ParticleEffect pe = ring == 1 ? s.dustGlow : s.dust;
                world.spawnParticles(pe, pos.x + Math.cos(a) * rr, y + ring * 0.02,
                        pos.z + Math.sin(a) * rr, 1, 0.01, 0.01, 0.01, 0.0);
            }
        }
        for (int g = 0; g < 5; g++) {
            double a = -tick * 0.05 + g * Math.PI * 2.0 / 5.0;
            double gx = pos.x + Math.cos(a) * r * 0.62;
            double gz = pos.z + Math.sin(a) * r * 0.62;
            for (int k = 0; k < 3; k++) {
                double da = tick * 0.15 + k * Math.PI * 2.0 / 3.0;
                world.spawnParticles(s.glow ? ParticleTypes.END_ROD : s.spark,
                        gx + Math.cos(da) * 0.1, y + 0.05, gz + Math.sin(da) * 0.1, 1, 0, 0.01, 0, 0.0);
            }
        }
        if (tick % 5 == 0) {
            double a = Math.random() * Math.PI * 2.0;
            double rr = Math.sqrt(Math.random()) * r;
            world.spawnParticles(s.main, pos.x + Math.cos(a) * rr, y, pos.z + Math.sin(a) * rr,
                    1, 0.02, 0.07, 0.02, 0.0);
        }
    }

    /** Мерцающий купол-полусфера (щиты, барьеры, святилища). */
    public static void domeShell(ServerWorld world, Vec3d base, ElementType el, VisualDefinition vis,
                                 double radius, int tick) {
        Settings s = FxPalette.of(el, vis);
        double r = Math.max(0.6, radius);
        int n = 30;
        double golden = Math.PI * (3.0 - Math.sqrt(5.0));
        for (int i = 0; i < n; i++) {
            double yy = i / (double) (n - 1);
            double rad = Math.sqrt(Math.max(0, 1.0 - yy * yy));
            double a = i * golden + tick * 0.02;
            boolean bright = (tick + i * 3) % 9 < 2;
            ParticleEffect pe = bright ? (s.glow ? ParticleTypes.END_ROD : s.dustGlow) : s.dust;
            world.spawnParticles(pe, base.x + Math.cos(a) * rad * r, base.y + yy * r,
                    base.z + Math.sin(a) * rad * r, 1, 0.01, 0.01, 0.01, 0.0);
        }
        if (tick % 4 == 0) {
            for (int i = 0; i < 10; i++) {
                double a = tick * 0.06 + i * Math.PI / 5.0;
                world.spawnParticles(s.main, base.x + Math.cos(a) * r, base.y + 0.08,
                        base.z + Math.sin(a) * r, 1, 0.03, 0.03, 0.03, 0.0);
            }
        }
    }

    // ======================================================================
    //  УТИЛИТЫ
    // ======================================================================

    private static String styleOf(String style) {
        return (style == null || style.isEmpty()) ? "default" : style;
    }
}