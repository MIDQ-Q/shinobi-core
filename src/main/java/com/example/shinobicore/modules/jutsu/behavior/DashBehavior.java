package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;
import net.minecraft.util.math.Vec3d;

public class DashBehavior implements JutsuBehavior {
    public static final String ID = "dash";

    @Override public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        float distance = ctx.behaviorData.has("distance")
            ? ctx.behaviorData.get("distance").getAsFloat() : 5.0f;
        int iframeTicks = ctx.behaviorData.has("iframeTicks")
            ? ctx.behaviorData.get("iframeTicks").getAsInt() : 4;

        Vec3d dir = ctx.caster.getRotationVector();
        Vec3d velocity = dir.multiply(distance * 0.2);

        ctx.caster.setVelocity(velocity.x, velocity.y, velocity.z);
        ctx.caster.velocityModified = true;
    }

    @Override
    public void onTick(BehaviorContext ctx) {}

    @Override
    public void onExpire(BehaviorContext ctx) {}
}