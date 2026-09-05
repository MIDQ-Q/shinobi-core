package com.example.shinobicore.ai;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.PropertyDefinition;
import com.example.shinobicore.jutsu.executor.CastContext;
import com.example.shinobicore.jutsu.executor.FormExecutor;
import com.example.shinobicore.jutsu.executor.Fx;
import com.example.shinobicore.jutsu.executor.VerificationLogger;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.PlayerLookup;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class AiStates {

    public static final AiState ROOT = new RootState();

    private static Vec3d ownerPos(AiBrain b) {
        if (b.owner == null) return null;
        ServerPlayerEntity p = ((ServerWorld) b.entity.getWorld()).getServer()
                .getPlayerManager().getPlayer(b.owner);
        return p == null ? null : p.getPos();
    }

    private static void explode(AiBrain b) {
        ServerWorld world = (ServerWorld) b.entity.getWorld();
        Vec3d center = b.entity.getPos();
        for (Object o : world.getOtherEntities(b.entity, new Box(center, center).expand(b.explodeRadius))) {
            if (o instanceof LivingEntity e && e.isAlive()) {
                e.damage(e.getDamageSources().magic(), b.explodeDamage);
            }
        }
        Fx.elementBurst(world, center, com.example.shinobicore.jutsu.enums.ElementType.FIRE, 40);
        VerificationLogger.log("KAMIKAZE", "exploded at " + center);
    }

    private static void telegraph(AiBrain b, String jutsuId, int dur) {
        try {
            Identifier id = com.example.shinobicore.network.ModPackets.CAST_START_ID;
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeInt(b.entity.getId());
            buf.writeString(jutsuId);
            buf.writeInt(dur);
            for (ServerPlayerEntity p : PlayerLookup.tracking(b.entity)) {
                ServerPlayNetworking.send(p, id, buf);
            }
        } catch (Throwable ignored) {}
    }

    private static class RootState implements AiState {
        public void tick(AiBrain b) {
            switch (b.behavior) {
                case "kamikaze" -> {
                    if (b.target == null || !b.target.isAlive()) b.target = AiSenses.findCombatTarget(b);
                    if (b.target != null) {
                        double d = b.entity.distanceTo(b.target);
                        AiMove.goTo(b, b.target.getPos(), 1.1);
                        if (d < 2.0) { explode(b); b.entity.discard(); }
                    } else {
                        Vec3d op = ownerPos(b);
                        if (op != null) AiMove.goTo(b, op, 0.8);
                    }
                }
                case "passive" -> {
                    if (b.stateTicks % 160 == 0) {
                        Vec3d p = b.entity.getPos().add(
                            (b.entity.getRandom().nextFloat() - 0.5) * 6, 0,
                            (b.entity.getRandom().nextFloat() - 0.5) * 6);
                        AiMove.goTo(b, p, 0.5);
                    }
                }
                case "follow" -> {
                    Vec3d op = ownerPos(b);
                    if (op != null && b.entity.getPos().distanceTo(op) > 4) AiMove.goTo(b, op, 0.9);
                    else AiMove.stop(b);
                }
                case "enemy" -> {
                    if (b.target == null || !b.target.isAlive()) b.target = AiSenses.findPlayerTarget(b);
                    if (b.target != null) {
                        double d = b.entity.distanceTo(b.target);
                        int castCd = Math.max(120, 260 - b.level * 8);
                        if (!b.jutsus.isEmpty() && d > 5 && d < 14 && b.cdOk("cast", castCd)) { b.setState(cast()); return; }
                        if (d <= 2.0 && b.cdOk("strike", 30)) { b.setState(strike()); return; }
                        AiMove.goTo(b, b.target.getPos(), 0.75);
                    } else if (b.home != null) {
                        if (b.entity.getPos().distanceTo(b.home) > 10) AiMove.goTo(b, b.home, 0.7);
                        else if (b.stateTicks % 180 == 0) {
                            AiMove.goTo(b, b.home.add((b.entity.getRandom().nextFloat() - 0.5) * 6, 0,
                                (b.entity.getRandom().nextFloat() - 0.5) * 6), 0.5);
                        }
                    }
                }
                default -> {
                    if (b.target == null || !b.target.isAlive()) b.target = AiSenses.findCombatTarget(b);
                    if (b.target != null) {
                        double d = b.entity.distanceTo(b.target);
                        int castCd = Math.max(120, 260 - b.level * 8);
                        if (!b.jutsus.isEmpty() && d > 4 && d < 14 && b.cdOk("cast", castCd)) { b.setState(cast()); return; }
                        if (d <= 2.0 && b.cdOk("strike", 30)) { b.setState(strike()); return; }
                        AiMove.goTo(b, b.target.getPos(), 0.9);
                    } else {
                        Vec3d op = ownerPos(b);
                        if (op != null && b.entity.getPos().distanceTo(op) > 5) AiMove.goTo(b, op, 0.8);
                        else AiMove.stop(b);
                    }
                }
            }
        }
    }

    public static AiState strike() { return new StrikeState(); }

    private static class StrikeState implements AiState {
        public void enter(AiBrain b) { AiMove.stop(b); }
        public void tick(AiBrain b) {
            if (b.stateTicks == 6) {
                if (b.target != null && b.target.isAlive() && b.entity.distanceTo(b.target) < 2.5) {
                    Vec3d dir = b.target.getPos().subtract(b.entity.getPos()).normalize().add(0, 0.25, 0);
                    b.target.damage(b.target.getDamageSources().mobAttack(b.entity), b.meleeDamage);
                    b.target.addVelocity(dir.x * 0.4, dir.y * 0.4, dir.z * 0.4);
                    b.target.velocityModified = true;
                }
            }
            if (b.stateTicks > 14) { b.navCd = 0; b.setState(ROOT); }
        }
    }

    public static AiState cast() { return new CastState(); }

    private static class CastState implements AiState {
        private String jutsu;
        public void enter(AiBrain b) {
            AiMove.stop(b);
            jutsu = b.jutsus.get(b.jutsuIndex++ % b.jutsus.size());
            telegraph(b, jutsu, 20);
        }
        public void tick(AiBrain b) {
            if (b.stateTicks % 4 == 0) {
                Fx.elementBurst((ServerWorld) b.entity.getWorld(), b.entity.getPos().add(0, 1, 0),
                        com.example.shinobicore.jutsu.enums.ElementType.NONE, 3);
            }
            if (b.stateTicks >= 20) {
                JutsuDefinition def = JutsuRegistry.get(jutsu);
                if (def != null) {
                    int mc = 0;
                    for (PropertyDefinition p : def.getProperties())
                        if (p.getId().equals("multi_target")) mc = p.getInt("count", 3);
                    CastContext ctx = new CastContext(b.entity, def, b.level, b.castScale,
                            def.getProperties(), def.getEffects(), mc);
                    FormExecutor.executeForm(ctx);
                    VerificationLogger.log("AI_CAST", b.entity.getName().getString()
                            + " cast " + jutsu + " scale=" + b.castScale);
                }
                b.navCd = 0;
                b.setState(ROOT);
            }
        }
    }

    public static AiState flee() { return new FleeState(); }

    private static class FleeState implements AiState {
        public void enter(AiBrain b) {
            b.entity.addStatusEffect(new StatusEffectInstance(StatusEffects.INVISIBILITY, 60, 0, false, false, false));
            Fx.elementBurst((ServerWorld) b.entity.getWorld(), b.entity.getPos().add(0, 1, 0),
                    com.example.shinobicore.jutsu.enums.ElementType.WIND, 25);
            if (b.target != null) {
                Vec3d away = b.entity.getPos().subtract(b.target.getPos()).normalize().multiply(14);
                b.navCd = 0;
                AiMove.goTo(b, b.entity.getPos().add(away), 1.1);
            }
            VerificationLogger.log("SMOKE_FLEE", b.entity.getName().getString() + " vanished in smoke");
        }
        public void tick(AiBrain b) {
            if (b.stateTicks > 200) b.entity.discard();
        }
    }
}