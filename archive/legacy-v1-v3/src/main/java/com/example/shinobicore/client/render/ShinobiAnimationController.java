package com.example.shinobicore.client.render;

import com.example.shinobicore.util.ModCompatibilityChecker;
import com.example.shinobicore.util.ShinobiLogger;
import net.minecraft.util.Identifier;

public final class ShinobiAnimationController {
    private ShinobiAnimationController() {}

    public static final Identifier HAND_SEALS_FAST = new Identifier("shinobicore", "hand_seals_fast");
    public static final Identifier HAND_SEALS_SLOW = new Identifier("shinobicore", "hand_seals_slow");
    public static final Identifier NARUTO_RUN = new Identifier("shinobicore", "naruto_run");
    public static final Identifier STANCE_AGGRESSIVE = new Identifier("shinobicore", "stance_aggressive");
    public static final Identifier STANCE_DEFENSIVE = new Identifier("shinobicore", "stance_defensive");
    public static final Identifier STANCE_SEIGAN = new Identifier("shinobicore", "stance_seigan");
    public static final Identifier WALL_RUN = new Identifier("shinobicore", "wall_run");
    public static final Identifier MEDITATION = new Identifier("shinobicore", "meditation");
    public static final Identifier KICK_COMBO = new Identifier("shinobicore", "kick_combo");

    private static boolean available = false;
    private static boolean initialized = false;

    public static void init() {
        if (initialized) return;
        initialized = true;
        available = ModCompatibilityChecker.hasPlayerAnimator();
        if (available) {
            ShinobiLogger.info("Player Animator detected - custom animations enabled");
        } else {
            ShinobiLogger.warn("Player Animator NOT detected - using vanilla fallback poses");
        }
    }

    public static void playHandSeals(boolean fast) {
        if (!available) return;
        ShinobiLogger.debug("Playing hand seals: {}", fast ? HAND_SEALS_FAST : HAND_SEALS_SLOW);
    }
    public static void stopAll() { if (available) ShinobiLogger.debug("Stopping all custom animations"); }
    public static void setNarutoRun(boolean active) { if (available) ShinobiLogger.debug("Naruto run: {}", active); }
    public static void setStance(String stanceId) { if (available) ShinobiLogger.debug("Setting stance: {}", stanceId); }
    public static boolean isAvailable() { return available; }
}