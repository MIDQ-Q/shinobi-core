package com.example.shinobicore.jutsu.custom;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.util.TickScheduler;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
public class LightningBeastBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld world)) return;
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 2.0f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.5f;
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();
        NinjaProjectileEntity proj = new NinjaProjectileEntity(world, player, look.multiply(speed), damage, radius, "lightning", "hound", 100);
        proj.setPosition(eye.x, eye.y, eye.z);
        world.spawnEntity(proj);
        TickScheduler.schedule(world, 1, 2, 40, w -> {
            if (proj.isRemoved()) return;
            LivingEntity target = findClosest(w, proj.getPos(), 16, player);
            if (target != null) {
                Vec3d to = target.getPos().add(0, target.getHeight() / 2, 0).subtract(proj.getPos()).normalize();
                Vec3d vel = proj.getVelocity();
                Vec3d newVel = vel.multiply(0.85).add(to.multiply(0.4));
                proj.setVelocity(newVel);
                proj.velocityDirty = true;
            }
        });
    }
    private LivingEntity findClosest(ServerWorld world, Vec3d from, float range, ServerPlayerEntity caster) {
        LivingEntity best = null; double bestDist = Double.MAX_VALUE;
        for (Entity e : world.getOtherEntities(caster, new net.minecraft.util.math.Box(from, from).expand(range))) {
            if (e instanceof LivingEntity liv && !liv.equals(caster)) {
                double d = liv.getPos().distanceTo(from);
                if (d < bestDist) { bestDist = d; best = liv; }
            }
        }
        return best;
    }
}