package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;
import net.minecraft.entity.Entity;
import net.minecraft.util.math.Vec3d;

public class ProjectileBehavior implements JutsuBehavior {
    public static final String ID = "projectile";

    @Override public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        float speed = ctx.behaviorData.has("projectileSpeed")
            ? ctx.behaviorData.get("projectileSpeed").getAsFloat() : 1.5f;
        float damage = ctx.behaviorData.has("projectileDamage")
            ? ctx.behaviorData.get("projectileDamage").getAsFloat() : 4.0f;
        int lifetime = ctx.behaviorData.has("projectileLifetimeTicks")
            ? ctx.behaviorData.get("projectileLifetimeTicks").getAsInt() : 80;

        damage *= ctx.chargeMultiplier;
        damage += ctx.casterLevel * 0.5f;

        Vec3d dir = ctx.caster.getRotationVector();
        // Spawn projectile entity at caster position + offset
        // Apply velocity dir * speed
    }

    @Override
    public void onTick(BehaviorContext ctx) {
        // Track projectile lifetime, apply trail effects
    }

    @Override
    public void onExpire(BehaviorContext ctx) {
        // Clean up projectile
    }
}