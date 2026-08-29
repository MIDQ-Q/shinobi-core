package com.example.shinobicore.client.combat;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Hit-Stop: freeze-frame on hit for combat feel.
 * Attacker freezes ~100ms, target freezes ~200ms.
 * This is NOT stun - just animation pause for impact weight.
 */
public class HitStopManager {
    private static final Map<Integer, Long> FROZEN = new ConcurrentHashMap<>();

    public static void freeze(int entityId, long ms) {
        long until = System.currentTimeMillis() + ms;
        Long existing = FROZEN.get(entityId);
        if (existing == null || until > existing) {
            FROZEN.put(entityId, until);
        }
    }

    public static boolean isFrozen(int entityId) {
        Long until = FROZEN.get(entityId);
        if (until == null) return false;
        if (System.currentTimeMillis() >= until) {
            FROZEN.remove(entityId);
            return false;
        }
        return true;
    }

    public static void clear() {
        FROZEN.clear();
    }
}