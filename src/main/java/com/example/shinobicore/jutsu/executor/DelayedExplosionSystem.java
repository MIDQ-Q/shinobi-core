package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.PropertyDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;
import java.util.UUID;

public class DelayedExplosionSystem {

    private static class Pending {
        final CastContext ctx;
        final Vec3d pos;
        final double radius;
        final double damage;
        int delay;
        final int chainDepth;
        Pending(CastContext ctx, Vec3d pos, double radius, double damage, int delay, int chainDepth) {
            this.ctx = ctx; this.pos = pos; this.radius = radius; this.damage = damage; 
            this.delay = delay; this.chainDepth = chainDepth;
        }
    }

    private static final List<Pending> ACTIVE = new ArrayList<>();
    private static final int MAX_CHAIN_DEPTH = 2;
    private static final int MAX_ACTIVE = 20;

    public static void schedule(CastContext ctx, Vec3d pos, PropertyDefinition prop) {
        if (ACTIVE.size() >= MAX_ACTIVE) {
            VerificationLogger.logError("DELAYED_EXPLOSION", "Too many active explosions, skipping");
            return;
        }
        int delay = prop.getInt("delay", 20);
        double radius = prop.getDouble("radius", 3);
        double damage = prop.getDouble("damage", 8) * ctx.damageScale;
        ACTIVE.add(new Pending(ctx, pos, radius, damage, delay, 0));
    }

    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        List<Pending> triggered = new ArrayList<>();
        Iterator<Pending> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Pending p = it.next();
            p.delay--;
            if (p.delay <= 0) { triggered.add(p); it.remove(); }
        }
        for (Pending p : triggered) explode(p);
    }

    private static void explode(Pending p) {
        ServerWorld world = p.ctx.world();
        Fx.elementBurst(world, p.pos, p.ctx.jutsu.getElement(), 40);
        Fx.impactRing(world, p.pos, p.ctx.jutsu.getElement(), p.radius, 0, 10);
        JutsuSoundHelper.playImpactSound(world, p.pos, p.ctx.jutsu);
        Set<UUID> hit = new HashSet<>();
        for (Object o : world.getOtherEntities(p.ctx.caster, new Box(p.pos, p.pos).expand(p.radius))) {
            if (!(o instanceof LivingEntity e) || !e.isAlive()) continue;
            if (!p.ctx.markHit(e)) continue;
            hit.add(e.getUuid());
            Combat.applyDamage(p.ctx, e, (float) p.damage);
        }
        // Chain explosion with DEPTH LIMIT
        PropertyDefinition ch = p.ctx.prop("chain_explosion");
        if (ch != null && p.chainDepth < MAX_CHAIN_DEPTH && ACTIVE.size() < MAX_ACTIVE) {
            int count = Math.min(ch.getInt("count", 3), 3); // Cap at 3 chains
            double r2 = ch.getDouble("radius", 2);
            LivingEntity last = null;
            for (UUID uid : hit) {
                for (Object o : world.getOtherEntities(p.ctx.caster, new Box(p.pos, p.pos).expand(p.radius))) {
                    if (o instanceof LivingEntity le && le.getUuid().equals(uid)) { last = le; break; }
                }
                if (last != null) break;
            }
            Vec3d current = last != null ? last.getPos() : p.pos;
            for (int i = 0; i < count && ACTIVE.size() < MAX_ACTIVE; i++) {
                Vec3d next = current.add(world.random.nextGaussian() * 2, 0, world.random.nextGaussian() * 2);
                ACTIVE.add(new Pending(p.ctx, next, r2, p.damage * 0.7, 10 + i * 5, p.chainDepth + 1));
            }
        }
    }
}