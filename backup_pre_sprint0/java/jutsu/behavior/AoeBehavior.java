package com.example.shinobicore.jutsu.behavior;
import com.example.shinobicore.progression.JutsuCastNotifier;

import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.util.EffectHelper;
import com.example.shinobicore.util.ParticleHelper;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.JsonHelper;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

import java.util.List;

/**
 * Area-of-effect damage at raycast point.
 * HLD Section 2.2.
 */
public class AoeBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
        JutsuCastNotifier.fire(player, "aoe", "ninjutsu");

        float range = JsonHelper.getFloat(params, "range", 20.0f);
        float aoeRadius = JsonHelper.getFloat(params, "aoe_radius", 4.0f);
        float knockback = JsonHelper.getFloat(params, "knockback", 1.0f);
        String particle = JsonHelper.getString(params, "particle", "flame");

        Vec3d start = player.getEyePos();
        Vec3d end = start.add(player.getRotationVector().multiply(range));

        HitResult hit = player.getWorld().raycast(new RaycastContext(
            start, end,
            RaycastContext.ShapeType.OUTLINE,
            RaycastContext.FluidHandling.NONE,
            player));

        Vec3d center = hit.getPos();

        // Damage entities
        Box box = new Box(center, center).expand(aoeRadius);
        List<Entity> targets = player.getWorld().getOtherEntities(player, box);
        for (Entity e : targets) {
            if (!(e instanceof LivingEntity le)) continue;
            le.damage(player.getDamageSources().magic(), damage);
            EffectHelper.applyAll(le, def);
            if (knockback > 0.0f) {
                Vec3d away = le.getPos().subtract(center);
                Vec3d flat = new Vec3d(away.x, 0.0, away.z);
                if (flat.lengthSquared() > 0.001) {
                    flat = flat.normalize().multiply(knockback * 0.3);
                    le.addVelocity(flat.x, 0.3, flat.z);
                    le.velocityModified = true;
                }
            }
        }

        // Particles
        for (int i = 0; i < 24; i++) {
            player.getWorld().addParticle(
                ParticleHelper.get(particle),
                center.x, center.y + 0.5, center.z,
                (player.getRandom().nextFloat() - 0.5f) * 0.8,
                player.getRandom().nextFloat() * 0.5,
                (player.getRandom().nextFloat() - 0.5f) * 0.8);
        }
    }
}