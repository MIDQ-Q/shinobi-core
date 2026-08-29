// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.progression.v3;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * SPRINT 18 client-side progression cache.
 */
public final class ProgressionClientState {
    private static int level = 1;
    private static int xp = 0;
    private static int sp = 0;

    private static final Map<String, Integer> STAT_LEVELS = new LinkedHashMap<>();
    private static final Map<String, Integer> STAT_XP = new LinkedHashMap<>();

    private ProgressionClientState() {}

    public static int getLevel() {
        return level;
    }

    public static int getXp() {
        return xp;
    }

    public static int getSp() {
        return sp;
    }

    public static Map<String, Integer> getStatLevels() {
        return STAT_LEVELS;
    }

    public static Map<String, Integer> getStatXp() {
        return STAT_XP;
    }

    public static void setLevel(int value) {
        level = Math.max(1, value);
    }

    public static void setXp(int value) {
        xp = Math.max(0, value);
    }

    public static void setSp(int value) {
        sp = Math.max(0, value);
    }

    public static void clearStats() {
        STAT_LEVELS.clear();
        STAT_XP.clear();
    }

    public static void setStat(String stat, int statLevel, int statXp) {
        if (stat == null || stat.isEmpty()) {
            return;
        }

        STAT_LEVELS.put(stat, Math.max(1, statLevel));
        STAT_XP.put(stat, Math.max(0, statXp));
    }
}