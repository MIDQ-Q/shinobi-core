package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.PropertyDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class HitProperties {

    public static void apply(CastContext ctx, Vec3d center) {
        ServerWorld world = ctx.world();
        for (PropertyDefinition prop : ctx.props) {
            switch (prop.getId()) {
                case "delayed_explosion" -> DelayedExplosionSystem.schedule(ctx, center, prop);
                case "explode_on_hit" -> {
                    double radius = prop.getDouble("radius", 3.0);
                    double dmg = prop.getDouble("damage", 8.0) * ctx.damageScale;
                    double kb = prop.getDouble("knockback", 0.5);
                    for (Object o : world.getOtherEntities(ctx.caster, new Box(center, center).expand(radius))) {
                        if (!(o instanceof LivingEntity e) || !e.isAlive()) continue;
                        if (!ctx.markHit(e)) continue;
                        Combat.applyDamage(ctx, e, (float) dmg);
                        Vec3d dir = e.getPos().subtract(center).normalize().add(0, 0.3, 0);
                        e.addVelocity(dir.x * kb, dir.y * kb, dir.z * kb);
                        e.velocityModified = true;
                    }
                    Fx.elementBurst(world, center, ctx.jutsu.getElement(), 40);
                    JutsuSoundHelper.playImpactSound(world, center, ctx.jutsu);
                }
                case "implosion" -> {
                    double radius = prop.getDouble("radius", 3.0);
                    double pull = prop.getDouble("pullForce", 2.0);
                    for (Object o : world.getOtherEntities(ctx.caster, new Box(center, center).expand(radius))) {
                        if (!(o instanceof LivingEntity e) || !e.isAlive()) continue;
                        Vec3d dir = center.subtract(e.getPos()).normalize();
                        e.addVelocity(dir.x * pull, 0.1, dir.z * pull);
                        e.velocityModified = true;
                    }
                }
                default -> {}
            }
        }
    }
}