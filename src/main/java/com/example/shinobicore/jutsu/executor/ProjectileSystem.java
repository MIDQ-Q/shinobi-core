package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
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
        final UUID owner;
        final JutsuDefinition jutsu;
        Vec3d pos;
        Vec3d vel;
        final double gravity;
        final double size;
        int lifetime;
        final boolean piercing;
        final Set<UUID> hit = new HashSet<>();

        Projectile(ServerPlayerEntity owner, JutsuDefinition jutsu, Vec3d pos, Vec3d vel,
                   double gravity, double size, int lifetime, boolean piercing) {
            this.owner = owner.getUuid();
            this.jutsu = jutsu;
            this.pos = pos;
            this.vel = vel;
            this.gravity = gravity;
            this.size = size;
            this.lifetime = lifetime;
            this.piercing = piercing;
        }
    }

    private static final List<Projectile> ACTIVE = new ArrayList<>();

    public static void spawn(ServerPlayerEntity player, JutsuDefinition jutsu, Vec3d dir,
                             double speed, double gravity, int lifetime, double size, boolean piercing) {
        Vec3d pos = player.getEyePos().add(dir.multiply(0.6));
        ACTIVE.add(new Projectile(player, jutsu, pos, dir.multiply(speed), gravity, size, lifetime, piercing));
        Fx.elementBurst(player.getServerWorld(), pos, jutsu.getElement(), 10);
    }

    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Projectile> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Projectile p = it.next();
            ServerPlayerEntity owner = server.getPlayerManager().getPlayer(p.owner);
            if (owner == null) { it.remove(); continue; }
            ServerWorld world = owner.getServerWorld();

            p.vel = p.vel.add(0, -p.gravity, 0);
            Vec3d next = p.pos.add(p.vel);

            // Block collision
            if (!world.getBlockState(BlockPos.ofFloored(next)).isAir()) {
                HitProperties.apply(world, owner, p.jutsu, next);
                Fx.elementBurst(world, next, p.jutsu.getElement(), 25);
                it.remove();
                continue;
            }

            // Entity collision
            LivingEntity target = null;
            for (Object o : world.getOtherEntities(owner, new Box(next, next).expand(p.size))) {
                if (o instanceof LivingEntity e && e.isAlive() && !p.hit.contains(e.getUuid())) {
                    target = e;
                    break;
                }
            }
            if (target != null) {
                p.hit.add(target.getUuid());
                EffectExecutor.applyEffects(owner, p.jutsu, target);
                HitProperties.apply(world, owner, p.jutsu, target.getPos());
                if (!p.piercing) { it.remove(); continue; }
            }

            p.pos = next;
            Fx.trail(world, p.pos, p.jutsu.getElement());
            p.lifetime--;
            if (p.lifetime <= 0) {
                Fx.elementBurst(world, p.pos, p.jutsu.getElement(), 15);
                it.remove();
            }
        }
    }
}