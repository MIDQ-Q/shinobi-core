package com.example.shinobicore.modules.jutsu.behavior;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public final class BehaviorRegistry {
    private static final Map<String, JutsuBehavior> BEHAVIORS = new ConcurrentHashMap<>();

    public static void register(JutsuBehavior behavior) {
        if (behavior != null && behavior.id() != null) {
            BEHAVIORS.put(behavior.id(), behavior);
        }
    }

    public static Optional<JutsuBehavior> get(String id) {
        return Optional.ofNullable(BEHAVIORS.get(id));
    }

    public static boolean isRegistered(String id) {
        return BEHAVIORS.containsKey(id);
    }

    public static void registerDefaults() {
        register(new ProjectileBehavior());
        register(new DashBehavior());
        register(new AoeBehavior());
        register(new WallBehavior());
        register(new GenjutsuBehavior());
        register(new UtilityBehavior());
        register(new MeleeBufferBehavior());
        ShinobiLogger.module("jutsu", "All 7 default behaviors registered.");
    }
}