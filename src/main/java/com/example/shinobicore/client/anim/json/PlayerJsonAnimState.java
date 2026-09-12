package com.example.shinobicore.client.anim.json;

import com.example.shinobicore.client.movement.AnimClock;
import net.minecraft.client.model.ModelPart;
import java.util.Map;

public class PlayerJsonAnimState {
    private static String currentAnim = "idle";
    private static boolean oneShot = false;
    // Combat Pack v1: время анимаций идёт через AnimClock — в боевом раже
    // (FrenzyClientState) оно визуально замедляется, сервер не затрагивается.
    private static long startTimeMs = 0;
    private static boolean active = false;
    public static float lastRootOffsetY = 0;

    public static void play(String animName, boolean isOneShot) {
        currentAnim = animName;
        oneShot = isOneShot;
        startTimeMs = AnimClock.scaledNow();
        active = true;
    }

    public static void stop() {
        active = false;
        currentAnim = "idle";
        oneShot = false;
        startTimeMs = AnimClock.scaledNow();
    }

    public static String getCurrentAnim() { return currentAnim; }
    public static boolean isOneShot() { return oneShot; }
    public static long getStartTimeMs() { return startTimeMs; }
    public static boolean isActive() { return active; }

    /** Returns true if currently playing a one-shot animation (attack, dodge, etc.) */
    public static boolean isPlayingOneShot() {
        return active && oneShot;
    }

    public static void tickAndApply(Map<String, ModelPart> parts,
                                boolean isMoving, boolean isSprinting, boolean isChakra,
                                boolean isSliding, boolean isJumping, boolean isFalling, float limbAngle,
                                boolean isCrawling, boolean isWallRunning, boolean isWaterRunning,
                                boolean isSneaking, boolean isChargingJump, boolean isMeditating) {
        if (!active) {
            String newAnim;

            if (isSliding) {
                // Slide: play "slide" intro, then loop "slide_process"
                JsonAnimLibrary.JsonAnim slideAnim = JsonAnimLibrary.get("slide");
                if (slideAnim != null && startTimeMs > 0 && "slide".equals(currentAnim)) {
                    float elapsed = (AnimClock.scaledNow() - startTimeMs) / 1000f;
                    newAnim = (elapsed >= slideAnim.length) ? "slide_process" : "slide";
                } else if ("slide_process".equals(currentAnim)) {
                    newAnim = "slide_process"; // keep looping
                } else {
                    newAnim = "slide"; // fresh slide start
                }
            }
            else if (isJumping)  newAnim = "jump_up";
            else if (isFalling)  newAnim = "fall";
            else if (isSprinting && isChakra) newAnim = "naruto_run";
            else if (isSprinting) newAnim = "run";
            else if (isMoving)   newAnim = "walk";
            else                 newAnim = "idle";

            // FIX: reset startTimeMs when animation changes (prevents visual jump)
            if (!newAnim.equals(currentAnim)) {
                startTimeMs = AnimClock.scaledNow();
            }
            currentAnim = newAnim;
            if (startTimeMs == 0) startTimeMs = AnimClock.scaledNow();
        }

        JsonAnimLibrary.JsonAnim anim = JsonAnimLibrary.get(currentAnim);
        if (anim == null) {
            anim = JsonAnimLibrary.get("idle");
        }
        if (anim == null) return;

        float timeSec;
        // === ФИКС: Синхронизируем анимации движения со скоростью игрока ===
        if (!active && (currentAnim.equals("walk") || currentAnim.equals("run") ||
                    currentAnim.equals("naruto_run") || currentAnim.equals("combat_walk") ||
                    currentAnim.equals("combat_run"))) {
            float cycle = (limbAngle % (float)(Math.PI * 2)) / (float)(Math.PI * 2);
            if (cycle < 0) cycle += 1.0f;
            timeSec = cycle * anim.length;
        } else {
            timeSec = (AnimClock.scaledNow() - startTimeMs) / 1000f;
        }

        // One-shot animations stop after completing
        if (oneShot && timeSec >= anim.length) {
            active = false;
            oneShot = false;
            startTimeMs = AnimClock.scaledNow();
            return;
        }

        float[] rootPos = JsonAnimLibrary.getRootOffset(anim, timeSec);
        lastRootOffsetY = (rootPos != null) ? rootPos[1] / 16.0f : 0f;
        JsonAnimLibrary.applyAnim(anim, timeSec, parts);
    }
}