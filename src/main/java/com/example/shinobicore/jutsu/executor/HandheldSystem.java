package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.FormDefinition;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;

public class HandheldSystem {

    private static class Held {
        final JutsuDefinition jutsu;
        int chargeTicks;
        int holdTicks;
        boolean ready;
        Held(JutsuDefinition jutsu) { this.jutsu = jutsu; }
    }

    private static final Map<UUID, Held> HELD = new HashMap<>();

    public static void start(ServerPlayerEntity player, JutsuDefinition jutsu) {
        HELD.put(player.getUuid(), new Held(jutsu));
        player.sendMessage(Text.literal("\u00a7bCharging " + jutsu.getName() + "..."), true);
    }

    public static void tick(MinecraftServer server) {
        if (HELD.isEmpty()) return;
        Iterator<Map.Entry<UUID, Held>> it = HELD.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<UUID, Held> entry = it.next();
            ServerPlayerEntity player = server.getPlayerManager().getPlayer(entry.getKey());
            if (player == null) { it.remove(); continue; }
            Held held = entry.getValue();
            FormDefinition form = held.jutsu.getForm();
            int chargeTime = form.getInt("chargeTime", 40);
            int holdDuration = form.getInt("holdDuration", 400);

            if (!held.ready) {
                held.chargeTicks++;
                if (held.chargeTicks >= chargeTime) {
                    held.ready = true;
                    player.sendMessage(Text.literal("\u00a7a" + held.jutsu.getName() + " ready! Strike your target!"), false);
                }
            } else {
                held.holdTicks++;
                Vec3d hand = player.getEyePos().add(player.getRotationVector().multiply(0.9)).add(0, -0.2, 0);
                Fx.trail(player.getServerWorld(), hand, held.jutsu.getElement());
                if (held.holdTicks >= holdDuration) {
                    player.sendMessage(Text.literal("\u00a77" + held.jutsu.getName() + " dissipated..."), false);
                    it.remove();
                }
            }
        }
    }

    public static void onPlayerHit(ServerPlayerEntity player, LivingEntity target) {
        Held held = HELD.get(player.getUuid());
        if (held == null || !held.ready) return;
        HELD.remove(player.getUuid());
        EffectExecutor.applyEffects(player, held.jutsu, target);
        HitProperties.apply(player.getServerWorld(), player, held.jutsu, target.getPos());
        Fx.elementBurst(player.getServerWorld(), target.getPos(), held.jutsu.getElement(), 30);
    }
}