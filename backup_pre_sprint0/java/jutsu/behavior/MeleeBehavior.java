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
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

import java.util.List;

/**
 * Short-range cone attack in front of the player.
 * HLD: Section 2.2
 */
public class MeleeBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
        JutsuCastNotifier.fire(player, "melee", "taijutsu");

        float range = JsonHelper.getFloat(params, "range", 3.0f);
        float radius = JsonHelper.getFloat(params, "radius", 2.0f);
        float knockback = JsonHelper.getFloat(params, "knockback", 0.5f);
        String particle = JsonHelper.getString(params, "particle", "crit");

        Vec3d look = player.getRotationVector();
        Vec3d dir = new Vec3d(look.x, 0.0, look.z);
        if (dir.lengthSquared() < 0.001) {
            dir = new Vec3d(0.0, 0.0, 1.0);
        }
        dir = dir.normalize();

        Vec3d center = player.getPos().add(dir.multiply(range * 0.7)).add(0.0, 1.0, 0.0);
        Box box = new Box(center, center).expand(radius);

        List<Entity> targets = player.getWorld().getOtherEntities(player, box);
        for (Entity e : targets) {
            if (!(e instanceof LivingEntity le)) {
                continue;
            }
            Vec3d to = le.getPos().subtract(player.getPos());
            Vec3d flat = new Vec3d(to.x, 0.0, to.z);
            if (flat.lengthSquared() < 0.001) {
                continue;
            }
            flat = flat.normalize();
            double dot = flat.x * dir.x + flat.z * dir.z;
            if (dot < 0.3) {
                continue;
            }
            le.damage(player.getDamageSources().magic(), damage);
            EffectHelper.applyAll(le, def);
            le.addVelocity(dir.x * knockback * 0.5, 0.2, dir.z * knockback * 0.5);
            le.velocityModified = true;
        }

        for (int i = 0; i < 8; i++) {
            player.getWorld().addParticle(
                ParticleHelper.get(particle),
                center.x, center.y, center.z,
                (player.getRandom().nextFloat() - 0.5f) * 0.4,
                (player.getRandom().nextFloat() - 0.5f) * 0.4,
                (player.getRandom().nextFloat() - 0.5f) * 0.4
            );
        }
    }
}