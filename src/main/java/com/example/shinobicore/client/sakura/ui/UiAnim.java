package com.example.shinobicore.client.sakura.ui;

import com.example.shinobicore.config.ModConfig;

/** Animation helpers: clamped progress, config gate, exponential smoothing. */
public final class UiAnim {
    private UiAnim() {}

    public static boolean animationsOn() {
        return ModConfig.instance.hud.uiAnimations;
    }

    public static float progress(long startMs, long nowMs, int durMs) {
        if (durMs <= 0) return 1f;
        float t = (nowMs - startMs) / (float) durMs;
        return t < 0f ? 0f : (t > 1f ? 1f : t);
    }

    /** Eased 0..1 for appear animations; snaps to 1 when animations disabled. */
    public static float openEase(long startMs, long nowMs, int durMs) {
        if (!animationsOn()) return 1f;
        return UiEase.outCubic(progress(startMs, nowMs, durMs));
    }

    /** Frame-rate independent smooth follow (for sliding indicators). */
    public static final class Smooth {
        private float value;
        private final float speed;

        public Smooth(float initial, float speed) {
            this.value = initial;
            this.speed = speed;
        }

        public float get() { return value; }
        public void set(float v) { value = v; }

        public float update(float target, long nowMs, long prevMs) {
            if (!animationsOn()) { value = target; return value; }
            float dt = (nowMs - prevMs) / 1000f;
            if (dt < 0f) dt = 0f;
            if (dt > 0.25f) dt = 0.25f;
            float k = 1f - (float) Math.exp(-speed * dt);
            value += (target - value) * k;
            return value;
        }
    }
}