// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.progression.v3;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 13 safe server-side progression foundation.
 *
 * This is an in-memory foundation.
 * Later it will be synced to components / persistent data.
 */
public final class ProgressionV3 {
    private static final Map<UUID, Data> DATA = new ConcurrentHashMap<>();

    private ProgressionV3() {}

    public static class Data {
        public int level = 1;
        public int xp = 0;
        public int sp = 0;

        public final Map<String, Integer> statLevels = new ConcurrentHashMap<>();
        public final Map<String, Integer> statXp = new ConcurrentHashMap<>();
    }

    public static Data get(UUID uuid) {
        return DATA.computeIfAbsent(uuid, id -> new Data());
    }

    public static int getXpForNextLevel(int level) {
        return 100 + (level - 1) * 50;
    }

    public static int getStatXpForNextLevel(int level) {
        return 80 + (level - 1) * 40;
    }

    public static void addXp(UUID uuid, int amount) {
        if (amount <= 0) {
            return;
        }

        Data data = get(uuid);
        data.xp += amount;

        while (data.xp >= getXpForNextLevel(data.level)) {
            data.xp -= getXpForNextLevel(data.level);
            data.level++;
            data.sp++;
        }
    }

    public static void addSp(UUID uuid, int amount) {
        Data data = get(uuid);
        data.sp = Math.max(0, data.sp + amount);
    }

    public static void addStatXp(UUID uuid, String stat, int amount) {
        if (stat == null || stat.isEmpty() || amount <= 0) {
            return;
        }

        Data data = get(uuid);

        int xp = data.statXp.getOrDefault(stat, 0) + amount;
        int level = data.statLevels.getOrDefault(stat, 1);

        while (xp >= getStatXpForNextLevel(level)) {
            xp -= getStatXpForNextLevel(level);
            level++;
        }

        data.statXp.put(stat, xp);
        data.statLevels.put(stat, level);
    }

    public static void reset(UUID uuid) {
        DATA.remove(uuid);
    }

    public static void resetAll() {
        DATA.clear();
    }
}