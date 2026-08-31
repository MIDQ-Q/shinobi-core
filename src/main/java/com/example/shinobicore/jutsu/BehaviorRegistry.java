package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;

import java.util.HashMap;
import java.util.Map;

public class BehaviorRegistry {
    private static final Map<String, JutsuBehavior> BEHAVIORS = new HashMap<>();
    private static final Map<String, JutsuBehavior> CUSTOM_CACHE = new HashMap<>();

    public static void register(String type, JutsuBehavior behavior) {
        BEHAVIORS.put(type, behavior);
        ShinobiCore.LOGGER.info("Registered jutsu behavior: {}", type);
    }

    public static JutsuBehavior get(String type) {
        return BEHAVIORS.getOrDefault(type, new DefaultBehavior());
    }

    public static JutsuBehavior getFor(JutsuDefinition def) {
        if ("custom".equals(def.type()) && def.behaviorClass() != null) {
            return CUSTOM_CACHE.computeIfAbsent(def.behaviorClass(), cls -> {
                try {
                    Class<?> c = Class.forName(cls);
                    return (JutsuBehavior) c.getDeclaredConstructor().newInstance();
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("Failed to load custom behavior {}: {}", cls, e.getMessage());
                    return new DefaultBehavior();
                }
            });
        }
        return get(def.type());
    }
}