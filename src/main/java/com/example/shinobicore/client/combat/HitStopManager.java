package com.example.shinobicore.client.combat;

import com.example.shinobicore.util.TimedCache;

/**
 * Hit-Stop: freeze-frame on hit for combat feel.
 * Attacker freezes ~100ms, target freezes ~200ms.
 * This is NOT stun - just animation pause for impact weight.
 */
public class HitStopManager {
    /**
     * H1: TTL кэша ОБЯЗАН быть не меньше максимальной длительности заморозки,
     * иначе TimedCache выбрасывает запись раньше времени и freeze(id, 900)
     * фактически даёт 500 мс. 2000 мс покрывает финишеры и добивания (Спринт 8).
     */
    public static final long MAX_FREEZE_MS = 2000L;
    private static final TimedCache<Integer, Long> FROZEN = new TimedCache<>(MAX_FREEZE_MS + 250L);

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