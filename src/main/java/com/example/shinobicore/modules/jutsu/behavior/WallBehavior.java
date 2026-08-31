package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;

public class WallBehavior implements JutsuBehavior {
    public static final String ID = "wall";

    @Override public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        int durationTicks = ctx.behaviorData.has("durationTicks")
            ? ctx.behaviorData.get("durationTicks").getAsInt() : 200;
        int width = ctx.behaviorData.has("width")
            ? ctx.behaviorData.get("width").getAsInt() : 5;
        int height = ctx.behaviorData.has("height")
            ? ctx.behaviorData.get("height").getAsInt() : 3;

        // Place temporary wall blocks in front of caster
        // Schedule removal after durationTicks
    }

    @Override
    public void onTick(BehaviorContext ctx) {}

    @Override
    public void onExpire(BehaviorContext ctx) {
        // Remove wall blocks
    }
}