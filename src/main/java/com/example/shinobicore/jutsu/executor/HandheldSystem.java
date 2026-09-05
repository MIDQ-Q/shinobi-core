package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.FormDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
import java.util.*;

public class HandheldSystem {
    private static class Held {
        final CastContext ctx; int chargeTicks, holdTicks; boolean ready;
        Held(CastContext ctx) { this.ctx = ctx; }
    }
    private static final Map<UUID, Held> HELD = new HashMap<>();
    private static final Map<UUID, Long> LAST_TRIGGER = new HashMap<>();
    public static void start(CastContext ctx) {
        HELD.put(ctx.caster.getUuid(), new Held(ctx));
        ctx.sendMsg(Text.literal("\u00a7bCharging " + ctx.jutsu.getName() + "..."), true);
    }
    public static void tick(MinecraftServer server) {
        if (HELD.isEmpty()) return;
        Iterator<Map.Entry<UUID, Held>> it = HELD.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<UUID, Held> entry = it.next();
            ServerPlayerEntity player = server.getPlayerManager().getPlayer(entry.getKey());
            if (player == null) { it.remove(); continue; }
            Held held = entry.getValue();
            FormDefinition form = held.ctx.jutsu.getForm();
            int chargeTime = form.getInt("chargeTime", 40);
            int holdDuration = form.getInt("holdDuration", 400);
            if (!held.ready) {
                held.chargeTicks++;
                if (held.chargeTicks >= chargeTime) {
                    held.ready = true;
                    player.sendMessage(Text.literal("\u00a7a" + held.ctx.jutsu.getName() + " ready! Strike or throw!"), false);
                }
            } else {
                held.holdTicks++;
                Vec3d hand = player.getEyePos().add(player.getRotationVector().multiply(0.9)).add(0, -0.2, 0);
                Fx.spinningSphere(player.getServerWorld(), hand, held.ctx.jutsu.getElement(), 0.5, held.holdTicks);
                if (held.holdTicks >= holdDuration) {
                    player.sendMessage(Text.literal("\u00a77" + held.ctx.jutsu.getName() + " dissipated..."), false);
                    it.remove();
                }
            }
        }
    }
    public static void onPlayerHit(ServerPlayerEntity player, LivingEntity target) {
        long now = System.currentTimeMillis();
        Long last = LAST_TRIGGER.get(player.getUuid());
        if (last != null && now - last < 250) return;
        Held held = HELD.get(player.getUuid());
        if (held == null || !held.ready) return;
        LAST_TRIGGER.put(player.getUuid(), now);
        CastContext ctx = held.ctx;
        boolean multiUse = ctx.hasProp("multi_use");
        if (!multiUse) HELD.remove(player.getUuid());
        if (ctx.markHit(target)) {
            EffectExecutor.applyEffects(ctx, target);
            HitProperties.apply(ctx, target.getPos());
            var ch = ctx.prop("chaining");
            if (ch != null) Combat.chain(ctx, target, ch);
        }
        Fx.impactRing(player.getServerWorld(), target.getPos(), ctx.jutsu.getElement(), 3.0, 0, 10);
    }
    public static void throwHeld(ServerPlayerEntity player) {
        Held held = HELD.get(player.getUuid());
        if (held == null || !held.ready) return;
        HELD.remove(player.getUuid());
        CastContext ctx = held.ctx;
        if (!ctx.hasProp("throwable")) {
            player.sendMessage(Text.literal("\u00a7cThis handheld is not throwable"), false);
            return;
        }
        Vec3d dir = player.getRotationVector();
        ProjectileSystem.spawn(ctx, dir);
        player.sendMessage(Text.literal("\u00a7aThrown!"), false);
    }
}