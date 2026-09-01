package com.example.shinobicore.client.combat;

import com.example.shinobicore.util.TimedCache;

/**
 * Hit-Stop: freeze-frame on hit for combat feel.
 * Attacker freezes ~100ms, target freezes ~200ms.
 * This is NOT stun - just animation pause for impact weight.
 */
public class HitStopManager {
    private static final TimedCache<Integer, Long> FROZEN = new TimedCache<>(500);

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
        return System.currentTimeMillis() < until;
    }

    public static void clear() {
        FROZEN.clear();
    }

    public static int size() {
        return FROZEN.size();
    }

    public static void cleanup() {
        FROZEN.cleanup();
    }
}