package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.combat.MarkTracker;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

public class ChainMeleeBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float range = params.has("range") ? params.get("range").getAsFloat() : 3.5f;
        int hits = params.has("hits") ? params.get("hits").getAsInt() : 6;
        float coneAngle = params.has("coneAngle") ? params.get("coneAngle").getAsFloat() : 90f;
        Vec3d look = player.getRotationVector();
        List<LivingEntity> targets = findInCone(world, player, look, range, coneAngle);
        float perHit = damage / hits;
        for (LivingEntity t : targets) {
            for (int i = 0; i < hits; i++) {
                t.damage(player.getDamageSources().magic(), MarkTracker.boost(t, perHit));
                Vec3d kb = t.getPos().subtract(player.getPos()).normalize().multiply(0.05);
                t.addVelocity(kb.x, 0.02, kb.z);
                t.velocityModified = true;
            }
            spawnParticles(world, t.getPos(), hits);
        }
        JutsuLogger.logBehavior("chain_melee", "targets=" + targets.size() + " hits=" + hits);
    }
    private List<LivingEntity> findInCone(ServerWorld world, ServerPlayerEntity a, Vec3d look, float r, float angle) {
        List<LivingEntity> out = new ArrayList<>();
        Vec3d dir = look.normalize();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class, a.getBoundingBox().expand(r + 1),
                t -> t != a && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() / 2.0, 0)
                    .subtract(a.getPos().add(0, a.getEyeHeight(a.getPose()), 0));
            if (to.length() > r) continue;
            double dot = dir.dotProduct(to.normalize());
            if (Math.toDegrees(Math.acos(Math.max(-1, Math.min(1, dot)))) <= angle / 2) out.add(e);
        }
        return out;
    }
    private void spawnParticles(ServerWorld world, Vec3d pos, int count) {
        for (int i = 0; i < count * 3; i++) {
            world.spawnParticles(ParticleTypes.CRIT,
                    pos.x + (Math.random() - 0.5) * 1.5,
                    pos.y + Math.random() * 1.5,
                    pos.z + (Math.random() - 0.5) * 1.5,
                    1, 0.1, 0.1, 0.1, 0.05);
        }
    }
}