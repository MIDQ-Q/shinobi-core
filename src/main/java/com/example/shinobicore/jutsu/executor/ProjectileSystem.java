package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.PropertyDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;
import java.util.UUID;

public class ProjectileSystem {

    private static class Projectile {
        final CastContext ctx;
        Vec3d pos, vel;
        final Vec3d dir0;
        final double gravity, size;
        int lifetime, age;
        final int maxLifetime;
        int pierceLeft, bounceLeft;
        boolean splitDone, removed;
        final boolean homing;
        final double turnRate;
        final String trajectory;
        final double amp, freq, spiralRate;
        final boolean invisible;
        final boolean silent;
        final Set<UUID> localHit = new HashSet<>();

        Projectile(CastContext ctx, Vec3d pos, Vec3d vel, double gravity, double size, int lifetime,
                   int pierceLeft, int bounceLeft, boolean homing, double turnRate,
                   String trajectory, double amp, double freq, double spiralRate,
                   boolean invisible, boolean silent) {
            this.ctx = ctx; this.pos = pos; this.vel = vel; this.dir0 = vel.normalize();
            this.gravity = gravity; this.size = size; this.lifetime = lifetime;
            this.maxLifetime = lifetime;
            this.pierceLeft = pierceLeft; this.bounceLeft = bounceLeft;
            this.homing = homing; this.turnRate = turnRate;
            this.trajectory = trajectory; this.amp = amp; this.freq = freq; this.spiralRate = spiralRate;
            this.invisible = invisible; this.silent = silent;
            this.age = 0;
        }
    }

    private static final List<Projectile> ACTIVE = new ArrayList<>();

    public static void spawn(CastContext ctx, Vec3d dir) {
        var form = ctx.jutsu.getForm();
        double speed = form.getDouble("speed", 1.4);
        double gravity = form.getDouble("gravity", 0.02);
        int lifetime = form.getInt("lifetime", 80);
        double size = form.getDouble("size", 0.5);

        PropertyDefinition volley = ctx.prop("volley");
        int volleyCount = 1;
        double volleySpread = 0;
        if (volley != null) {
            volleyCount = volley.getInt("count", 5);
            volleySpread = volley.getDouble("spreadAngle", 30);
        }

        if (ctx.hasProp("no_gravity")) { gravity = 0; VerificationLogger.logProperty(ctx.jutsu.getId(), "no_gravity", "gravity disabled"); }
        PropertyDefinition ga = ctx.prop("gravity_affected");
        if (ga != null) gravity *= ga.getDouble("strength", 2.0);

        int pierce = 0;
        PropertyDefinition pi = ctx.prop("piercing");
        if (pi != null) { pierce = pi.getInt("count", 3); VerificationLogger.logProperty(ctx.jutsu.getId(), "piercing", "count=" + pierce); }
        int bounce = 0;
        PropertyDefinition bo = ctx.prop("bouncing");
        if (bo != null) { bounce = bo.getInt("count", 2); VerificationLogger.logProperty(ctx.jutsu.getId(), "bouncing", "count=" + bounce); }
        boolean homing = ctx.hasProp("homing");
        double turnRate = 0.1;
        PropertyDefinition ho = ctx.prop("homing");
        if (ho != null) { turnRate = ho.getDouble("turnRate", 0.1); VerificationLogger.logProperty(ctx.jutsu.getId(), "homing", "turnRate=" + turnRate); }
        boolean invisible = ctx.hasProp("invisible_projectile");
        boolean silent = ctx.hasProp("silent");
        if (ctx.hasProp("splitting")) VerificationLogger.logProperty(ctx.jutsu.getId(), "splitting", "count=" + ctx.prop("splitting").getInt("count", 3));
        if (ctx.hasProp("chaining")) VerificationLogger.logProperty(ctx.jutsu.getId(), "chaining", "count=" + ctx.prop("chaining").getInt("count", 3));

        String trajectory = "straight";
        double amp = 1, freq = 0.3, spiralRate = 0.2, arcH = 0;
        for (PropertyDefinition p : ctx.props) {
            switch (p.getId()) {
                case "trajectory_arc" -> { trajectory = "arc"; arcH = p.getDouble("arcHeight", 3); }
                case "trajectory_wave" -> { trajectory = "wave"; amp = p.getDouble("amplitude", 1); freq = p.getDouble("frequency", 0.3); }
                case "trajectory_spiral" -> { trajectory = "spiral"; spiralRate = p.getDouble("spiralRate", 0.2); amp = p.getDouble("amplitude", 0.6); }
                default -> {}
            }
        }

        Vec3d vel = dir.normalize().multiply(speed);
        if (trajectory.equals("arc")) vel = vel.add(0, arcH * 0.08, 0);

        Vec3d pos = ctx.caster.getEyePos().add(dir.normalize().multiply(0.6));

        int count = volleyCount > 1 ? volleyCount : form.getInt("count", 1);
        double spread = volleyCount > 1 ? volleySpread : form.getDouble("spread", 0);

        for (int i = 0; i < count; i++) {
            double angle = count <= 1 ? 0 : (-spread / 2.0 + spread * i / Math.max(1, count - 1.0)) * Math.PI / 180.0;
            Vec3d d = angle == 0 ? vel : rotY(vel, angle);
            ACTIVE.add(new Projectile(ctx, pos, d, gravity, size, lifetime, pierce, bounce, homing, turnRate,
                    trajectory, amp, freq, spiralRate, invisible, silent));
        }

        if (!silent && !invisible) Fx.elementBurst(ctx.world(), pos, ctx.jutsu.getElement(), 8);
    }

    private static Vec3d rotY(Vec3d v, double a) {
        double c = Math.cos(a), s = Math.sin(a);
        return new Vec3d(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
    }

    public static void tick(net.minecraft.server.MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        List<Projectile> spawned = new ArrayList<>();
        Iterator<Projectile> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Projectile p = it.next();
            ServerWorld world = p.ctx.world();
            p.age++;

            if (p.homing) {
                LivingEntity t = Combat.nearestEnemy(world, p.ctx.caster, p.pos, 16, null);
                if (t != null) {
                    double speed = p.vel.length();
                    Vec3d to = t.getPos().add(0, 1, 0).subtract(p.pos).normalize().multiply(speed);
                    p.vel = p.vel.add(to.subtract(p.vel).multiply(p.turnRate));
                }
            }

            p.vel = p.vel.add(0, -p.gravity, 0);
            Vec3d prev = p.pos;
            p.pos = p.pos.add(p.vel);

            Vec3d display = p.pos;
            if (p.trajectory.equals("wave") || p.trajectory.equals("spiral")) {
                Vec3d perp = new Vec3d(-p.dir0.z, 0, p.dir0.x);
                if (perp.lengthSquared() > 0.001) perp = perp.normalize();
                if (p.trajectory.equals("wave")) {
                    display = p.pos.add(perp.multiply(Math.sin(p.age * p.freq) * p.amp * 0.5));
                } else {
                    double a = p.age * p.spiralRate;
                    display = p.pos.add(perp.multiply(Math.cos(a) * p.amp)).add(0, Math.sin(a) * p.amp * 0.4, 0);
                }
            }

            BlockPos bp = BlockPos.ofFloored(display);
            BlockPos pp = BlockPos.ofFloored(prev);
            if (!world.getBlockState(bp).isAir()) {
                if (p.bounceLeft > 0) {
                    p.bounceLeft--;
                    if (bp.getY() != pp.getY()) p.vel = new Vec3d(p.vel.x, -p.vel.y * 0.8, p.vel.z);
                    else if (bp.getX() != pp.getX()) p.vel = new Vec3d(-p.vel.x * 0.8, p.vel.y, p.vel.z);
                    else p.vel = new Vec3d(p.vel.x, p.vel.y, -p.vel.z * 0.8);
                    p.pos = prev;
                } else {
                    HitProperties.apply(p.ctx, display);
                    it.remove();
                    continue;
                }
            }

            for (Object o : world.getOtherEntities(p.ctx.caster, new Box(display, display).expand(p.size))) {
                if (!(o instanceof LivingEntity e) || !e.isAlive() || e.equals(p.ctx.caster)) continue;
                if (p.localHit.contains(e.getUuid())) continue;
                if (!p.ctx.markHit(e)) break;
                p.localHit.add(e.getUuid());
                EffectExecutor.applyEffects(p.ctx, e);
                HitProperties.apply(p.ctx, e.getPos());
                PropertyDefinition ch = p.ctx.prop("chaining");
                if (ch != null) Combat.chain(p.ctx, e, ch);
                PropertyDefinition st = p.ctx.prop("stick_on_hit");
                if (st != null) StickSystem.stick(p.ctx, e, st.getInt("duration", 100));
                if (p.pierceLeft > 0) { p.pierceLeft--; }
                else { p.removed = true; break; }
            }
            if (p.removed) { it.remove(); continue; }

            PropertyDefinition sp = p.ctx.prop("splitting");
            if (sp != null && !p.splitDone && p.age >= p.maxLifetime / 3) {
                p.splitDone = true;
                int count = sp.getInt("count", 3);
                double angle = sp.getDouble("angle", 30) * Math.PI / 180.0;
                Fx.elementBurst(world, display, p.ctx.jutsu.getElement(), 25);
                JutsuSoundHelper.playImpactSound(world, display, p.ctx.jutsu);
                VerificationLogger.logProperty(p.ctx.jutsu.getId(), "splitting", "SPLIT into " + count + " shards at age=" + p.age);
                for (int i = 0; i < count; i++) {
                    double a = -angle + (2 * angle) * i / Math.max(1, count - 1);
                    Projectile shard = new Projectile(p.ctx, display, rotY(p.vel, a), p.gravity, p.size * 0.7,
                            p.maxLifetime / 2, 0, 0, p.homing, p.turnRate, "straight", 0, 0, 0, p.invisible, p.silent);
                    spawned.add(shard);
                }
                it.remove();
                continue;
            }

            if (!p.invisible) Fx.trail(world, display, p.ctx.jutsu.getElement());
            p.lifetime--;
            if (p.lifetime <= 0) {
                if (!p.invisible) Fx.elementBurst(world, display, p.ctx.jutsu.getElement(), 12);
                it.remove();
            }
        }
        ACTIVE.addAll(spawned);
    }

    public static void clearAll() { ACTIVE.clear(); }
}