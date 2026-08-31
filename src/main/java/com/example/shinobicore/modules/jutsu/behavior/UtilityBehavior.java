package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;

public class UtilityBehavior implements JutsuBehavior {
    public static final String ID = "utility";

    @Override public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        String effectType = ctx.behaviorData.has("effectType")
            ? ctx.behaviorData.get("effectType").getAsString() : "heal";
        float amount = ctx.behaviorData.has("amount")
            ? ctx.behaviorData.get("amount").getAsFloat() : 4.0f;

        // Apply utility effect based on effectType
        // heal, buff, teleport, etc.
    }

    @Override
    public void onTick(BehaviorContext ctx) {}

    @Override
    public void onExpire(BehaviorContext ctx) {}
}