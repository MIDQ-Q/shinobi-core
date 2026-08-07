package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;

import java.util.HashMap;
import java.util.Map;

public class BehaviorRegistry {
    private static final Map<String, JutsuBehavior> BEHAVIORS = new HashMap<>();

    public static void register(String type, JutsuBehavior behavior) {
        BEHAVIORS.put(type, behavior);
        ShinobiCore.LOGGER.info("Registered jutsu behavior: {}", type);
    }

    public static JutsuBehavior get(String type) {
        return BEHAVIORS.getOrDefault(type, new DefaultBehavior());
    }
}