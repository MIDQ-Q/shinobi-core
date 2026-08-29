package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.combat.MarkTracker;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class ContinuousFlameBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 8f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.5f;
        int burnDur = params.has("burnDuration") ? params.get("burnDuration").getAsInt() : 4;
        Vec3d start = player.getEyePos();
        Vec3d dir = player.getRotationVector();
        int hitCount = 0;
        for (float d = 1f; d <= range; d += 0.5f) {
            Vec3d p = start.add(dir.multiply(d));
            for (Entity e : world.getOtherEntities(player,
                    new net.minecraft.util.math.Box(p, p).expand(radius))) {
                if (e instanceof LivingEntity liv && !liv.equals(player)) {
                    if (damage > 0) liv.damage(player.getDamageSources().inFire(), MarkTracker.boost(liv, damage * 0.3f));
                    liv.setOnFireFor(burnDur);
                    hitCount++;
                }
            }
            for (int i = 0; i < 8; i++) {
                world.spawnParticles(ParticleTypes.FLAME,
                        p.x + (Math.random() - 0.5) * radius,
                        p.y + (Math.random() - 0.5) * radius,
                        p.z + (Math.random() - 0.5) * radius,
                        1, dir.x * 0.2, dir.y * 0.2, dir.z * 0.2, 0.04);
            }
            if (d % 2 == 0) {
                world.spawnParticles(ParticleTypes.LARGE_SMOKE, p.x, p.y, p.z, 1, 0.05, 0.05, 0.05, 0.01);
            }
        }
        JutsuLogger.logBehavior("continuous_flame", "range=" + range + " hits=" + hitCount);
    }
}