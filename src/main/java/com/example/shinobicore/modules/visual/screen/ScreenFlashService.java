package com.example.shinobicore.modules.visual.screen;

public final class ScreenFlashService {
    private static int flashColor = 0;
    private static int flashDuration = 0;
    private static int flashTick = 0;

    public static void init() {
        flashColor = 0;
        flashDuration = 0;
        flashTick = 0;
    }

    public static void flash(int color, int durationTicks) {
        if (durationTicks > flashDuration) {
            flashColor = color;
            flashDuration = durationTicks;
            flashTick = 0;
        }
    }

    public static void tick() {
        if (flashDuration <= 0) return;
        flashTick++;
        if (flashTick >= flashDuration) {
            flashColor = 0;
            flashDuration = 0;
        }
    }

    public static float getCurrentAlpha() {
        if (flashDuration <= 0) return 0.0f;
        float progress = (float) flashTick / flashDuration;
        return Math.max(0.0f, 0.3f * (1.0f - progress)); // Max alpha 0.3
    }

    public static int getColor() { return flashColor; }
    public static boolean isFlashing() { return flashDuration > 0; }
}