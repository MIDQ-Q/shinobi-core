package com.example.shinobicore.client.dojutsu;

/**
 * S6-07..S6-12: Client-side sharingan state.
 * Stores stage, active flag, usage/stress progress.
 */
public class SharinganClientState {
    public static boolean active = false;
    public static int stageLevel = 0;
    public static int usageProgress = 0;
    public static int stressCount = 0;

    public static boolean isActive() { return active && stageLevel > 0; }
    public static boolean hasOneTomoe() { return stageLevel >= 1; }
    public static boolean hasTwoTomoe() { return stageLevel >= 2; }
    public static boolean hasThreeTomoe() { return stageLevel >= 3; }
    public static boolean hasMangekyo() { return stageLevel >= 4; }

    public static float getOverlayAlpha() {
        switch (stageLevel) {
            case 1: return 0.10f;
            case 2: return 0.15f;
            case 3: return 0.20f;
            case 4: return 0.30f;
            default: return 0f;
        }
    }

    public static int getParticleCount() {
        switch (stageLevel) {
            case 1: return 3;
            case 2: return 6;
            case 3: return 10;
            case 4: return 15;
            default: return 0;
        }
    }

    public static void clear() {
        active = false;
        stageLevel = 0;
        usageProgress = 0;
        stressCount = 0;
    }
}