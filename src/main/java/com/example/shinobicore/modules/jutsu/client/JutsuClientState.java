package com.example.shinobicore.modules.jutsu.client;

import com.example.shinobicore.modules.jutsu.cast.CastPhase;

public final class JutsuClientState {
    private static boolean isCasting = false;
    private static float castProgress = 0.0f;
    private static CastPhase currentPhase = CastPhase.IDLE;
    private static String currentJutsuId = "";
    private static int selectedSlot = 0;

    public static void updateFromServer(boolean casting, float progress, String phaseStr, String jutsuId) {
        isCasting = casting;
        castProgress = progress;
        currentJutsuId = jutsuId;
        try {
            currentPhase = CastPhase.valueOf(phaseStr.toUpperCase());
        } catch (Exception e) {
            currentPhase = CastPhase.IDLE;
        }
    }

    public static void setSelectedSlot(int slot) { selectedSlot = slot; }
    public static int getSelectedSlot() { return selectedSlot; }
    public static boolean isCasting() { return isCasting; }
    public static float getCastProgress() { return castProgress; }
    public static CastPhase getCurrentPhase() { return currentPhase; }
    public static String getCurrentJutsuId() { return currentJutsuId; }
    
    public static void reset() {
        isCasting = false;
        castProgress = 0.0f;
        currentPhase = CastPhase.IDLE;
        currentJutsuId = "";
    }
}