package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.combat.MarkTracker;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

public class TrackingKunaiBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        float range = params.has("range") ? params.get("range").getAsFloat() : 24f;
        long markMs = params.has("markMs") ? params.get("markMs").getAsLong() : 120000L;
        Vec3d eye = player.getEyePos();
        Vec3d dir = player.getRotationVector().normalize();
        LivingEntity best = null;
        double bestDist = Double.MAX_VALUE;
        for (LivingEntity e : player.getWorld().getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(range), t -> t != player && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() * 0.6, 0).subtract(eye);
            double dist = to.length();
            if (dist > range) continue;
            double ang = Math.acos(Math.max(-1, Math.min(1, dir.dotProduct(to.normalize()))));
            if (ang <= Math.toRadians(4) && dist < bestDist) { best = e; bestDist = dist; }
        }
        if (best == null) {
            player.sendMessage(Text.literal("\u00a7cNo target in sight."), false);
            return;
        }
        MarkTracker.mark(best, markMs);
        best.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, (int)(markMs / 50), 0, false, false));
        player.sendMessage(Text.literal("\u00a7aTracking mark placed on " + best.getName().getString() + "!"), false);
        JutsuLogger.logBehavior("tracking_kunai", "target=" + best.getName().getString());
    }
}