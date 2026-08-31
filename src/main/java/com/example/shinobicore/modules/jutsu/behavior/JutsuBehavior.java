package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;

public interface JutsuBehavior {
    String id();
    void onRelease(BehaviorContext ctx);
    default void onTick(BehaviorContext ctx) {}
    default void onExpire(BehaviorContext ctx) {}
    default boolean shouldInterrupt(BehaviorContext ctx) { return false; }
}