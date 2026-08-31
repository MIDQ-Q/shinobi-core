package com.example.shinobicore.modules.visual.camera;

public final class CameraShakeService {
    private static float shakeIntensity = 0.0f;
    private static int shakeDuration = 0;
    private static int shakeTick = 0;

    public static void init() {
        shakeIntensity = 0.0f;
        shakeDuration = 0;
        shakeTick = 0;
    }

    public static void shake(float intensity, int durationTicks) {
        if (intensity > shakeIntensity) {
            shakeIntensity = intensity;
            shakeDuration = durationTicks;
            shakeTick = 0;
        }
    }

    public static void tick() {
        if (shakeDuration <= 0) return;
        shakeTick++;
        if (shakeTick >= shakeDuration) {
            shakeIntensity = 0.0f;
            shakeDuration = 0;
            return;
        }
    }
    
    public static float getIntensity() { return shakeIntensity; }
    public static boolean isShaking() { return shakeDuration > 0; }
}