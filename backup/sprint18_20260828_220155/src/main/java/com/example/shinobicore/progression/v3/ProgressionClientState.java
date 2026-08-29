// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.progression.v3;

/**
 * SPRINT 13 client-side progression cache.
 *
 * Later this will be synced from server.
 */
public final class ProgressionClientState {
    private static int level = 1;
    private static int xp = 0;
    private static int sp = 0;

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

    public static void setLevel(int value) {
        level = Math.max(1, value);
    }

    public static void setXp(int value) {
        xp = Math.max(0, value);
    }

    public static void setSp(int value) {
        sp = Math.max(0, value);
    }
}