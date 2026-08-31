package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;

public class MeleeBufferBehavior implements JutsuBehavior {
    public static final String ID = "melee_buffer";

    @Override public String id() { return ID; }

    @Override
    public void onRelease(BehaviorContext ctx) {
        float damageBonus = ctx.behaviorData.has("damageBonus")
            ? ctx.behaviorData.get("damageBonus").getAsFloat() : 2.0f;
        int durationTicks = ctx.behaviorData.has("durationTicks")
            ? ctx.behaviorData.get("durationTicks").getAsInt() : 100;

        // Apply temporary melee damage buff to caster
        // Store buff data for CombatModule to read
    }

    @Override
    public void onTick(BehaviorContext ctx) {}

    @Override
    public void onExpire(BehaviorContext ctx) {
        // Remove buff
    }
}