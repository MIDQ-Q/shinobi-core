package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.FormDefinition;
import com.example.shinobicore.jutsu.core.PropertyDefinition;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.*;

public class BeamSystem {
    private static class Beam {
        final CastContext ctx;
        final double maxRange, width;
        int ticksLeft;
        final int tickRate;
        final boolean channeled;
        final double chakraPerTick;
        final Set<UUID> hitThisTick = new HashSet<>();
        Beam(CastContext ctx, double maxRange, double width, int duration, int tickRate, boolean channeled, double chakraPerTick) {
            this.ctx = ctx; this.maxRange = maxRange; this.width = width;
            this.ticksLeft = duration; this.tickRate = Math.max(1, tickRate);
            this.channeled = channeled; this.chakraPerTick = chakraPerTick;
        }
    }
    private static final List<Beam> ACTIVE = new ArrayList<>();
    public static void start(CastContext ctx, FormDefinition form) {
        double maxRange = form.getDouble("maxRange", 16.0);
        double width = form.getDouble("width", 1.0);
        int duration = form.getInt("duration", 60);
        int tickRate = form.getInt("tickRate", 5);
        boolean channeled = ctx.hasProp("channeled");
        double chakraPerTick = 0;
        if (channeled) { PropertyDefinition ch = ctx.prop("channeled"); chakraPerTick = ch.getDouble("chakraPerTick", 0.5); }
        ACTIVE.add(new Beam(ctx, maxRange, width, duration, tickRate, channeled, chakraPerTick));
        JutsuSoundHelper.playCastSound(ctx.caster, ctx.jutsu);
    }
    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Beam> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Beam b = it.next();
            LivingEntity caster = b.ctx.caster;
            if (!caster.isAlive()) { it.remove(); continue; }
            if (b.channeled && caster instanceof ServerPlayerEntity sp) {
                NinjaPlayerData data = ((NinjaDataHolder) sp).shinobicore_getData();
                if (data.getCurrentChakra() < b.chakraPerTick) {
                    b.ctx.sendMsg(net.minecraft.text.Text.literal("\u00a7cChakra depleted! Beam ended"), false);
                    it.remove(); continue;
                }
                data.setCurrentChakra((float) (data.getCurrentChakra() - b.chakraPerTick));
            }
            ServerWorld world = b.ctx.world();
            Vec3d start = caster.getEyePos();
            Vec3d dir = caster.getRotationVector().normalize();
            Vec3d end = start.add(dir.multiply(b.maxRange));
            for (int i = 0; i < (int) b.maxRange; i++) {
                Vec3d p = start.add(dir.multiply(i));
                Fx.trail(world, p, b.ctx.jutsu.getElement());
            }
            b.ticksLeft--;
            if (b.ticksLeft % b.tickRate == 0) {
                b.hitThisTick.clear();
                for (Object o : world.getOtherEntities(caster, new Box(start, end).expand(b.width))) {
                    if (!(o instanceof LivingEntity e) || !e.isAlive() || e.equals(caster)) continue;
                    Vec3d toE = e.getPos().add(0, e.getHeight() / 2, 0).subtract(start);
                    double proj = toE.dotProduct(dir);
                    if (proj < 0 || proj > b.maxRange) continue;
                    Vec3d closest = start.add(dir.multiply(proj));
                    double dist = closest.distanceTo(e.getPos().add(0, e.getHeight() / 2, 0));
                    if (dist <= b.width && b.ctx.markHit(e)) { EffectExecutor.applyEffects(b.ctx, e); b.hitThisTick.add(e.getUuid()); }
                }
            }
            if (b.ticksLeft <= 0) it.remove();
        }
    }
}