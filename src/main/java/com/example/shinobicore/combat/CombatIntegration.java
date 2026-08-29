package com.example.shinobicore.combat;

import com.example.shinobicore.util.ModCompatibilityChecker;
import com.example.shinobicore.util.ShinobiLogger;

public final class CombatIntegration {
    private CombatIntegration() {}
    private static boolean initialized = false;

    public static void init() {
        if (initialized) return;
        initialized = true;
        if (ModCompatibilityChecker.hasBetterCombat()) {
            ShinobiLogger.info("Better Combat detected - delegating melee combat to BC");
        } else {
            ShinobiLogger.warn("Better Combat NOT detected - using fallback melee system");
        }
    }

    public static float calculateMeleeDamage(float baseDamage, int taijutsuLevel, int kenjutsuLevel, boolean hasWeapon) {
        float mult = 1.0f + (taijutsuLevel * 0.02f);
        if (hasWeapon) mult += (kenjutsuLevel * 0.03f);
        return baseDamage * mult;
    }

    public static boolean shouldProcDojutsu(String dojutsuId, int stage) {
        return Math.random() < (0.05 * stage);
    }
}