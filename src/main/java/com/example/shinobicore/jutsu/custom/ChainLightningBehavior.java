package com.example.shinobicore.jutsu.custom;

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
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class ChainLightningBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        int maxTargets = params.has("maxTargets") ? params.get("maxTargets").getAsInt() : 5;
        float chainRange = params.has("chainRange") ? params.get("chainRange").getAsFloat() : 8f;
        float damageFalloff = params.has("damageFalloff") ? params.get("damageFalloff").getAsFloat() : 0.85f;
        Vec3d start = player.getEyePos().add(player.getRotationVector().multiply(2));
        LivingEntity first = findClosest(world, start, chainRange, player, null);
        if (first == null) return;
        Set<LivingEntity> hit = new HashSet<>();
        LivingEntity current = first;
        float currentDamage = damage;
        for (int i = 0; i < maxTargets && current != null; i++) {
            hit.add(current);
            current.damage(player.getDamageSources().magic(), currentDamage);
            spawnBolt(world, start, current.getPos().add(0, current.getHeight() / 2, 0));
            current.setOnFireFor(1);
            currentDamage *= damageFalloff;
            start = current.getPos().add(0, current.getHeight() / 2, 0);
            current = findClosest(world, start, chainRange, player, hit);
        }
        JutsuLogger.logBehavior("chain_lightning", "targets=" + hit.size() + " damage=" + damage);
    }
    private LivingEntity findClosest(ServerWorld world, Vec3d from, float range,
                                      ServerPlayerEntity caster, Set<LivingEntity> exclude) {
        LivingEntity best = null;
        double bestDist = Double.MAX_VALUE;
        for (Entity e : world.getOtherEntities(caster,
                new net.minecraft.util.math.Box(from, from).expand(range))) {
            if (e instanceof LivingEntity liv && !liv.equals(caster)) {
                if (exclude != null && exclude.contains(liv)) continue;
                double d = liv.getPos().distanceTo(from);
                if (d < bestDist) { bestDist = d; best = liv; }
            }
        }
        return best;
    }
    private void spawnBolt(ServerWorld world, Vec3d from, Vec3d to) {
        Vec3d dir = to.subtract(from).normalize();
        double dist = from.distanceTo(to);
        for (double d = 0; d < dist; d += 0.3) {
            Vec3d p = from.add(dir.multiply(d));
            world.spawnParticles(ParticleTypes.ELECTRIC_SPARK, p.x, p.y, p.z, 1, 0, 0, 0, 0);
        }
    }
}