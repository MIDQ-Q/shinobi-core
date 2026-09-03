package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.PropertyDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class HitProperties {

    public static void apply(ServerWorld world, ServerPlayerEntity owner, JutsuDefinition jutsu, Vec3d center) {
        for (PropertyDefinition prop : jutsu.getProperties()) {
            switch (prop.getId()) {
                case "explode_on_hit" -> {
                    double radius = prop.getDouble("radius", 3.0);
                    double dmg = prop.getDouble("damage", 8.0);
                    double kb = prop.getDouble("knockback", 0.5);
                    for (Object o : world.getOtherEntities(owner, new Box(center, center).expand(radius))) {
                        if (!(o instanceof LivingEntity e) || !e.isAlive()) continue;
                        e.damage(owner.getDamageSources().magic(), (float) dmg);
                        Vec3d dir = e.getPos().subtract(center).normalize().add(0, 0.3, 0);
                        e.addVelocity(dir.x * kb, dir.y * kb, dir.z * kb);
                        e.velocityModified = true;
                    }
                    Fx.elementBurst(world, center, jutsu.getElement(), 40);
                }
                default -> { /* other properties come later */ }
            }
        }
    }
}