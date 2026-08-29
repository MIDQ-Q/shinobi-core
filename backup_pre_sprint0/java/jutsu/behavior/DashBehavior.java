package com.example.shinobicore.jutsu.behavior;
import com.example.shinobicore.progression.JutsuCastNotifier;

import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.util.ParticleHelper;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.JsonHelper;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

import java.util.List;

/**
 * Forward dash dealing damage along the path.
 * HLD: Section 2.2
 */
public class DashBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
        JutsuCastNotifier.fire(player, "dash", "taijutsu");

        float distance = JsonHelper.getFloat(params, "distance", 5.0f);
        float hitRadius = JsonHelper.getFloat(params, "hitRadius", 2.0f);
        float knockback = JsonHelper.getFloat(params, "knockback", 1.0f);

        Vec3d look = player.getRotationVector();
        Vec3d dir = new Vec3d(look.x, 0.0, look.z);
        if (dir.lengthSquared() < 0.001) {
            dir = new Vec3d(0.0, 0.0, 1.0);
        }
        dir = dir.normalize();

        Vec3d start = player.getPos();
        Vec3d end = start.add(dir.multiply(distance));

        HitResult hit = player.getWorld().raycast(new RaycastContext(
            start.add(0.0, 1.0, 0.0), end.add(0.0, 1.0, 0.0),
            RaycastContext.ShapeType.COLLIDER,
            RaycastContext.FluidHandling.NONE,
            player
        ));

        Vec3d target = end;
        if (hit.getType() != HitResult.Type.MISS) {
            target = hit.getPos().add(0.0, -1.0, 0.0);
        }

        Box pathBox = new Box(start, target).expand(hitRadius);
        List<Entity> targets = player.getWorld().getOtherEntities(player, pathBox);
        for (Entity e : targets) {
            if (!(e instanceof LivingEntity le)) {
                continue;
            }
            le.damage(player.getDamageSources().magic(), damage);
            le.addVelocity(dir.x * knockback * 0.5, 0.3, dir.z * knockback * 0.5);
            le.velocityModified = true;
        }

        player.getWorld().addParticle(ParticleTypes.POOF,
            start.x, start.y + 1.0, start.z, 0.0, 0.1, 0.0);

        player.setPosition(target.x, target.y, target.z);
        player.velocityModified = true;

        player.getWorld().addParticle(ParticleHelper.get("cloud"),
            target.x, target.y + 1.0, target.z, 0.0, 0.1, 0.0);
    }
}