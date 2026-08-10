package com.example.shinobicore.combat;

public class TaijutsuCombo {
    public static final int MAX_STEPS = 4;
    public static final long COMBO_TIMEOUT_MS = 1500;

    private static final float[] STEP_DAMAGE = {1.0f, 1.0f, 1.2f, 1.8f};
    private static final float[] STEP_KNOCKBACK = {0.3f, 0.3f, 0.4f, 1.2f};

    public static float getDamageMult(int step) {
        if (step < 0) step = 0;
        if (step >= MAX_STEPS) step = MAX_STEPS - 1;
        return STEP_DAMAGE[step];
    }

    public static float getKnockback(int step) {
        if (step < 0) step = 0;
        if (step >= MAX_STEPS) step = MAX_STEPS - 1;
        return STEP_KNOCKBACK[step];
    }

    public static boolean isFinisher(int step) {
        return step == MAX_STEPS - 1;
    }
}