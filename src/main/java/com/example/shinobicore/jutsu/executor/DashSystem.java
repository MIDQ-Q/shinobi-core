package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.FormDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.UUID;

public class DashSystem {

    private static class Dash {
        final CastContext ctx;
        int ticks;
        final boolean damageOnPath;
        final List<UUID> hit = new ArrayList<>();
        Dash(CastContext ctx, int ticks, boolean damageOnPath) {
            this.ctx = ctx; this.ticks = ticks; this.damageOnPath = damageOnPath;
        }
    }

    private static final List<Dash> ACTIVE = new ArrayList<>();

    public static void start(CastContext ctx, FormDefinition form) {
        double distance = form.getDouble("distance", 8.0);
        double speed = form.getDouble("speed", 3.0);
        boolean damageOnPath = form.getBoolean("damageOnPath", true);
        Vec3d look = ctx.caster.getRotationVector();
        ctx.caster.addVelocity(look.x * speed * 0.5, 0.1, look.z * speed * 0.5);
        ctx.caster.velocityModified = true;
        int ticks = (int) (distance / Math.max(0.5, speed) * 5);
        ACTIVE.add(new Dash(ctx, Math.max(4, ticks), damageOnPath));
        JutsuSoundHelper.playCastSound(ctx.caster, ctx.jutsu);
        Fx.elementBurst(ctx.world(), ctx.caster.getPos().add(0, 1, 0), ctx.jutsu.getElement(), 15);
    }

    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Dash> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Dash d = it.next();
            LivingEntity player = d.ctx.caster;
            if (!player.isAlive()) { it.remove(); continue; }
            if (d.damageOnPath) {
                for (Object o : d.ctx.world().getOtherEntities(player, player.getBoundingBox().expand(1.5))) {
                    if (!(o instanceof LivingEntity e) || !e.isAlive() || d.hit.contains(e.getUuid())) continue;
                    if (!d.ctx.markHit(e)) continue;
                    d.hit.add(e.getUuid());
                    EffectExecutor.applyEffects(d.ctx, e);
                    HitProperties.apply(d.ctx, e.getPos());
                }
            }
            Fx.trail(d.ctx.world(), player.getPos().add(0, 1, 0), d.ctx.jutsu.getElement());
            d.ticks--;
            if (d.ticks <= 0) it.remove();
        }
    }
}