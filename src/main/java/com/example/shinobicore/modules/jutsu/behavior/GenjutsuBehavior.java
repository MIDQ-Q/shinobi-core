package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;

public class GenjutsuBehavior implements JutsuBehavior {
    public static final String ID = "genjutsu";

    @Override public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        int durationTicks = ctx.behaviorData.has("durationTicks")
            ? ctx.behaviorData.get("durationTicks").getAsInt() : 100;
        float range = ctx.behaviorData.has("range")
            ? ctx.behaviorData.get("range").getAsFloat() : 8.0f;

        // Apply genjutsu effect to targets in range
        // Confusion, slowness, or custom effect
    }

    @Override
    public void onTick(BehaviorContext ctx) {}

    @Override
    public void onExpire(BehaviorContext ctx) {}
}