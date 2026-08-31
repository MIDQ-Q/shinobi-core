package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;
import net.minecraft.entity.Entity;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.List;

public class AoeBehavior implements JutsuBehavior {
    public static final String ID = "aoe";

    @Override public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        float radius = ctx.behaviorData.has("radius")
            ? ctx.behaviorData.get("radius").getAsFloat() : 5.0f;
        float damage = ctx.behaviorData.has("damage")
            ? ctx.behaviorData.get("damage").getAsFloat() : 6.0f;

        damage *= ctx.chargeMultiplier;
        damage += ctx.casterLevel * 0.5f;

        Vec3d center = ctx.caster.getPos().add(ctx.caster.getRotationVector().multiply(3.0));
        Box box = new Box(center.x - radius, center.y - radius, center.z - radius,
                          center.x + radius, center.y + radius, center.z + radius);

        List<Entity> targets = ctx.world.getOtherEntities(ctx.caster, box);
        for (Entity target : targets) {
            if (target.isAttackable()) {
                target.damage(ctx.caster.getDamageSources().magic(), damage);
            }
        }
    }

    @Override
    public void onTick(BehaviorContext ctx) {}

    @Override
    public void onExpire(BehaviorContext ctx) {}
}