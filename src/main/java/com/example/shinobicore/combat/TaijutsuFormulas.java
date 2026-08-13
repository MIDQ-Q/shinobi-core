package com.example.shinobicore.combat;

import com.example.shinobicore.config.ModConfig;

public class TaijutsuFormulas {
    public static float baseDamage(int taijutsuLevel) {
        return ModConfig.instance.taijutsu.baseDamage + taijutsuLevel * ModConfig.instance.taijutsu.damagePerLevel;
    }

    public static float computeDamage(int taijutsuLevel, TaijutsuStyle style,
                                       boolean chakraMode, int comboStep, boolean exhausted) {
        float base = baseDamage(taijutsuLevel);
        float comboMult = TaijutsuCombo.getDamageMult(comboStep);
        float styleMult = style.getDamageMult();
        float chakraMult = chakraMode ? ModConfig.instance.taijutsu.chakraModeDamageMult : 1.0f;
        float exhaustMult = exhausted ? 0.5f : 1.0f;
        return base * comboMult * styleMult * chakraMult * exhaustMult;
    }

    public static int attackCooldownTicks(TaijutsuStyle style, boolean chakraMode) {
        float baseCooldown = 12.0f;
        float speedMult = style.getSpeedMult() * (chakraMode ? ModConfig.instance.taijutsu.chakraModeSpeedMult : 1.0f);
        return Math.max(4, (int) (baseCooldown / speedMult));
    }

    // === НОВОЕ: уровень разблокировки Strong Fist из конфига ===
    public static int strongFistUnlockLevel() {
        return ModConfig.instance.taijutsu.strongFistUnlockLevel;
    }

    public static boolean canUseStrongFist(int taijutsuLevel) {
        return taijutsuLevel >= strongFistUnlockLevel();
    }

    // === PHASE7_SPEED_SCALING ===
    public static int attackCooldownTicks(TaijutsuStyle style, boolean chakraMode, int taijutsuLevel) {
        float baseCooldown = 12.0f;
        float speedMult = style.getSpeedMult() * (chakraMode ? ModConfig.instance.taijutsu.chakraModeSpeedMult : 1.0f);
        float levelMult = 1.0f + taijutsuLevel * 0.003f;
        return Math.max(3, (int) (baseCooldown / (speedMult * levelMult)));
    }
}