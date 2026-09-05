package com.example.shinobicore.ai;

import com.example.shinobicore.jutsu.enums.ElementType;
import com.example.shinobicore.jutsu.executor.Fx;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;

public class AiSystem {
    private static final Map<UUID, AiBrain> BRAINS = new HashMap<>();
    private static final Map<UUID, UUID> OWNER_ATTACKER = new HashMap<>();
    private static MinecraftServer server;

    public static void noteOwnerAttacker(UUID owner, UUID attacker) { OWNER_ATTACKER.put(owner, attacker); }

    public static LivingEntity ownerAttacker(UUID owner) {
        UUID a = OWNER_ATTACKER.get(owner);
        if (a == null || server == null) return null;
        ServerPlayerEntity p = server.getPlayerManager().getPlayer(owner);
        if (p == null) return null;
        for (Object o : p.getServerWorld().getOtherEntities(p, new Box(p.getPos(), p.getPos()).expand(32))) {
            if (o instanceof LivingEntity le && le.getUuid().equals(a)) {
                OWNER_ATTACKER.remove(owner);
                return le;
            }
        }
        return null;
    }

    public static boolean hasBrain(UUID u) { return BRAINS.containsKey(u); }
    public static AiBrain get(UUID u) { return BRAINS.get(u); }

    public static void add(AiBrain b) {
        BRAINS.put(b.entity.getUuid(), b);
        b.setState(AiStates.ROOT);
    }

    public static long countForOwner(UUID owner) {
        return BRAINS.values().stream().filter(b -> owner.equals(b.owner)).count();
    }

    public static void removeOldestForOwner(UUID owner) {
        BRAINS.values().stream().filter(b -> owner.equals(b.owner)).findFirst()
            .ifPresent(b -> { b.entity.discard(); BRAINS.remove(b.entity.getUuid()); });
    }

    /** Enemies react when a player starts casting nearby. */
    public static void notifyPlayerCast(ServerPlayerEntity p) {
        for (AiBrain b : BRAINS.values()) {
            if (!"enemy".equals(b.behavior) || !b.entity.isAlive()) continue;
            if (b.entity.getPos().distanceTo(p.getPos()) > 14) continue;
            if (!b.cdOk("react", 60)) continue;
            if (b.personality == 1) {
                // cautious: sidestep to make you miss
                Vec3d to = b.entity.getPos().subtract(p.getPos());
                Vec3d perp = new Vec3d(-to.z, 0, to.x).normalize();
                if (b.entity.getRandom().nextBoolean()) perp = perp.multiply(-1);
                b.entity.addVelocity(perp.x * 0.7, 0.2, perp.z * 0.7);
                b.entity.velocityModified = true;
            } else {
                // aggressive: rush to interrupt
                Vec3d to = p.getPos().subtract(b.entity.getPos()).normalize();
                b.entity.addVelocity(to.x * 0.6, 0.1, to.z * 0.6);
                b.entity.velocityModified = true;
            }
            Fx.elementBurst((ServerWorld) b.entity.getWorld(), b.entity.getPos().add(0, 1, 0), ElementType.WIND, 4);
        }
    }

    public static void tick(MinecraftServer s) {
        server = s;
        if (BRAINS.isEmpty()) return;
        Iterator<AiBrain> it = BRAINS.values().iterator();
        while (it.hasNext()) {
            AiBrain b = it.next();
            if (!b.entity.isAlive()) { it.remove(); continue; }
            b.cooldowns.replaceAll((k, v) -> Math.max(0, v - 1));
            b.navCd = Math.max(0, b.navCd - 1);
            if (b.lifetime > 0) {
                b.lifetime--;
                if (b.lifetime <= 0) {
                    Fx.elementBurst((ServerWorld) b.entity.getWorld(), b.entity.getPos(), ElementType.YIN, 15);
                    b.entity.discard();
                    it.remove();
                    continue;
                }
            }
            b.stateTicks++;
            if (b.state != null) b.state.tick(b);

            // Anti-stuck: if standing still in ROOT with a live target - nudge
            if (b.state == AiStates.ROOT && b.target != null && b.target.isAlive()) {
                double dx = b.entity.getX() - b.lastX;
                double dz = b.entity.getZ() - b.lastZ;
                if (dx * dx + dz * dz < 0.0004) b.stuck++; else b.stuck = 0;
                if (b.stuck > 40) {
                    b.stuck = 0;
                    b.navCd = 0;
                    Vec3d d = b.target.getPos().subtract(b.entity.getPos());
                    d = new Vec3d(d.x, 0, d.z);
                    if (d.lengthSquared() > 1e-6) {
                        d = d.normalize();
                        b.entity.addVelocity(d.x * 0.3, 0.3, d.z * 0.3);
                        b.entity.velocityModified = true;
                    }
                    b.entity.addVelocity(0, 0.4, 0);
                    b.entity.velocityModified = true;
                }
            }
            b.lastX = b.entity.getX();
            b.lastZ = b.entity.getZ();
        }
    }
}