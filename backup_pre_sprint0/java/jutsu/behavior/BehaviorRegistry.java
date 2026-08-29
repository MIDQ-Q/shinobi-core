package com.example.shinobicore.jutsu.behavior;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.HashMap;
import java.util.Map;

/**
 * Maps string IDs to JutsuBehavior instances.
 * HLD: Section 2.2 - safe registration, no Class.forName crashes.
 */
public final class BehaviorRegistry {

    private static final Map<String, JutsuBehavior> BEHAVIORS = new HashMap<>();

    private static final JutsuBehavior FALLBACK = new JutsuBehavior() {
        @Override
        public void cast(ServerPlayerEntity player, JutsuDefinition def, JsonObject params, float damage) {
            ShinobiCore.LOGGER.warn("[WARN] Fallback behavior triggered for jutsu {}", def.id());
        }
    };

    private BehaviorRegistry() {}

    public static void register(String id, JutsuBehavior behavior) {
        BEHAVIORS.put(id, behavior);
        ShinobiCore.LOGGER.info("Registered behavior: {}", id);
    }

    public static boolean has(String id) {
        return BEHAVIORS.containsKey(id);
    }

    public static JutsuBehavior get(String id) {
        JutsuBehavior b = BEHAVIORS.get(id);
        if (b == null) {
            return FALLBACK;
        }
        return b;
    }

    /**
     * Resolve behavior for a definition. Custom behaviorClass wins over behavior.
     */
    public static JutsuBehavior getFor(JutsuDefinition def) {
        String key = def.behavior();
        if (def.hasCustomBehavior()) {
            key = def.behaviorClass();
        }
        JutsuBehavior b = BEHAVIORS.get(key);
        if (b == null) {
            ShinobiCore.LOGGER.warn("[WARN] Jutsu '{}' has unknown behavior '{}'", def.id(), key);
            return FALLBACK;
        }
        return b;
    }
}