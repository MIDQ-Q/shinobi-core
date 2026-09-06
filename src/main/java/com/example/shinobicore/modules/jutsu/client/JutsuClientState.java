package com.example.shinobicore.modules.jutsu.client;

/**
 * Client-side state mirror for jutsu casting.
 * Updated by server sync packets.
 */
public final class JutsuClientState {
    private static boolean casting = false;
    private static float castProgress = 0f;
    private static String currentJutsuId = "";
    private static String castPhase = "IDLE";

    private JutsuClientState() {}

    public static void update(boolean isCasting, float progress, String phase, String jutsuId) {
        casting = isCasting;
        castProgress = progress;
        castPhase = phase;
        currentJutsuId = jutsuId;
    }

    public static boolean isCasting() { return casting; }
    public static float getCastProgress() { return castProgress; }
    public static String getCastPhase() { return castPhase; }
    public static String getCurrentJutsuId() { return currentJutsuId; }

    public static void reset() {
        casting = false;
        castProgress = 0f;
        castPhase = "IDLE";
        currentJutsuId = "";
    }
}