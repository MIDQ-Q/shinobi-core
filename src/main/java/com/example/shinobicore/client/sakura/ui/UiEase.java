package com.example.shinobicore.client.sakura.ui;

/** Easing curves for UI motion. t is 0..1. */
public final class UiEase {
    private UiEase() {}

    public static float linear(float t) { return t; }

    public static float outCubic(float t) {
        float u = 1 - t;
        return 1 - u * u * u;
    }

    public static float outQuint(float t) {
        float u = 1 - t;
        return 1 - u * u * u * u * u;
    }

    public static float inOutCubic(float t) {
        return t < 0.5f ? 4 * t * t * t : 1 - (float) Math.pow(-2 * t + 2, 3) / 2;
    }

    /** Overshoot ease for pops/unlocks. */
    public static float outBack(float t) {
        float c1 = 1.70158f, c3 = c1 + 1;
        float u = t - 1;
        return 1 + c3 * u * u * u + c1 * u * u;
    }
}