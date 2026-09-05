package com.example.shinobicore.jutsu.executor;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;

public class CooldownSystem {
    private static final Map<UUID, Map<String, Integer>> COOLDOWNS = new HashMap<>();

    public static boolean isOnCooldown(UUID player, String jutsuId) {
        Map<String, Integer> m = COOLDOWNS.get(player);
        return m != null && m.getOrDefault(jutsuId, 0) > 0;
    }

    public static int getRemaining(UUID player, String jutsuId) {
        Map<String, Integer> m = COOLDOWNS.get(player);
        return m == null ? 0 : m.getOrDefault(jutsuId, 0);
    }

    public static void start(UUID player, String jutsuId, int ticks) {
        COOLDOWNS.computeIfAbsent(player, k -> new HashMap<>()).put(jutsuId, ticks);
    }

    public static void tick() {
        Iterator<Map.Entry<UUID, Map<String, Integer>>> it = COOLDOWNS.entrySet().iterator();
        while (it.hasNext()) {
            Map<String, Integer> m = it.next().getValue();
            m.replaceAll((k, v) -> v > 0 ? v - 1 : 0);
        }
    }

    public static void clear(UUID player) {
        COOLDOWNS.remove(player);
    }

    /** Haste: reduce all current cooldowns by given ticks. */
    public static void reduceAll(UUID player, int ticks) {
        Map<String, Integer> m = COOLDOWNS.get(player);
        if (m == null) return;
        m.replaceAll((k, v) -> Math.max(0, v - ticks));
    }
}
