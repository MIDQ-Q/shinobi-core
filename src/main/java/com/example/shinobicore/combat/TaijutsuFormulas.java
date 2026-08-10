package com.example.shinobicore.combat;

public class TaijutsuFormulas {

    public static float baseDamage(int taijutsuLevel) {
        return 2.0f + taijutsuLevel * 0.3f;
    }

    public static float computeDamage(int taijutsuLevel, TaijutsuStyle style,
                                      boolean chakraMode, int comboStep, boolean exhausted) {
        float base = baseDamage(taijutsuLevel);
        float comboMult = TaijutsuCombo.getDamageMult(comboStep);
        float styleMult = style.getDamageMult();
        float chakraMult = chakraMode ? 1.5f : 1.0f;
        float exhaustMult = exhausted ? 0.5f : 1.0f;
        return base * comboMult * styleMult * chakraMult * exhaustMult;
    }

    public static int attackCooldownTicks(TaijutsuStyle style, boolean chakraMode) {
        float baseCooldown = 12.0f;
        float speedMult = style.getSpeedMult() * (chakraMode ? 1.3f : 1.0f);
        return Math.max(4, (int) (baseCooldown / speedMult));
    }

    public static boolean canUseStrongFist(int taijutsuLevel) {
        return taijutsuLevel >= 50;
    }
}