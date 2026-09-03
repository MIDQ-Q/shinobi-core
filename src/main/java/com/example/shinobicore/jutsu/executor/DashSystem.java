package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.FormDefinition;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;
import java.util.UUID;

public class DashSystem {

    private static class Dash {
        final UUID player;
        final JutsuDefinition jutsu;
        int ticks;
        final boolean damageOnPath;
        final Set<UUID> hit = new HashSet<>();
        Dash(ServerPlayerEntity player, JutsuDefinition jutsu, int ticks, boolean damageOnPath) {
            this.player = player.getUuid();
            this.jutsu = jutsu;
            this.ticks = ticks;
            this.damageOnPath = damageOnPath;
        }
    }

    private static final List<Dash> ACTIVE = new ArrayList<>();

    public static void start(ServerPlayerEntity player, JutsuDefinition jutsu, FormDefinition form) {
        double distance = form.getDouble("distance", 8.0);
        double speed = form.getDouble("speed", 3.0);
        boolean damageOnPath = form.getBoolean("damageOnPath", true);

        Vec3d look = player.getRotationVector();
        player.addVelocity(look.x * speed * 0.5, 0.1, look.z * speed * 0.5);
        player.velocityModified = true;

        int ticks = (int) (distance / Math.max(0.5, speed) * 5);
        ACTIVE.add(new Dash(player, jutsu, Math.max(4, ticks), damageOnPath));
        Fx.elementBurst(player.getServerWorld(), player.getPos().add(0, 1, 0), jutsu.getElement(), 15);
    }

    public static void tick(MinecraftServer server) {
        if (ACTIVE.isEmpty()) return;
        Iterator<Dash> it = ACTIVE.iterator();
        while (it.hasNext()) {
            Dash d = it.next();
            ServerPlayerEntity player = server.getPlayerManager().getPlayer(d.player);
            if (player == null) { it.remove(); continue; }

            if (d.damageOnPath) {
                for (Object o : player.getServerWorld().getOtherEntities(player, player.getBoundingBox().expand(1.5))) {
                    if (!(o instanceof LivingEntity e) || !e.isAlive() || d.hit.contains(e.getUuid())) continue;
                    d.hit.add(e.getUuid());
                    EffectExecutor.applyEffects(player, d.jutsu, e);
                    HitProperties.apply(player.getServerWorld(), player, d.jutsu, e.getPos());
                }
            }
            Fx.trail(player.getServerWorld(), player.getPos().add(0, 1, 0), d.jutsu.getElement());
            d.ticks--;
            if (d.ticks <= 0) it.remove();
        }
    }
}