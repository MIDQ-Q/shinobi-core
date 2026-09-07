package com.example.shinobicore.client.anim.json;

import net.minecraft.client.model.ModelPart;
import java.util.Map;

public class PlayerJsonAnimState {
    private static String currentAnim = "idle";
    private static boolean oneShot = false;
    private static long startTimeMs = 0;
    private static boolean active = false;

    public static void play(String animName, boolean isOneShot) {
        currentAnim = animName;
        oneShot = isOneShot;
        startTimeMs = System.currentTimeMillis();
        active = true;
    }

    public static void stop() {
        active = false;
        currentAnim = "idle";
        oneShot = false;
        startTimeMs = System.currentTimeMillis();
    }

    public static String getCurrentAnim() { return currentAnim; }
    public static boolean isOneShot() { return oneShot; }
    public static long getStartTimeMs() { return startTimeMs; }

    public static boolean isActive() {
        return active;
    }

    /** Returns true if currently playing a one-shot animation (attack, dodge, etc.) */
    public static boolean isPlayingOneShot() {
        return active && oneShot;
    }

    public static void tickAndApply(Map<String, ModelPart> parts, boolean isMoving,
                                     boolean isSprinting, boolean isChakra,
                                     boolean isSliding, boolean isRolling) {
        if (!active) {
            // Auto-select looping animation based on state
            if (isSliding) currentAnim = "slide";
            else if (isRolling) currentAnim = "roll";
            else if (isSprinting && isChakra) currentAnim = "naruto_run";
            else if (isSprinting) currentAnim = "run";
            else if (isMoving) currentAnim = "walk";
            else currentAnim = "idle";

            if (startTimeMs == 0) startTimeMs = System.currentTimeMillis();
        }

        JsonAnimLibrary.JsonAnim anim = JsonAnimLibrary.get(currentAnim);
        if (anim == null) {
            anim = JsonAnimLibrary.get("idle");
        }
        if (anim == null) return;

        float timeSec = (System.currentTimeMillis() - startTimeMs) / 1000f;

        // One-shot animations stop after completing
        if (oneShot && timeSec >= anim.length) {
            active = false;
            oneShot = false;
            startTimeMs = System.currentTimeMillis();
            return;
        }

        JsonAnimLibrary.applyAnim(anim, timeSec, parts);
    }
}