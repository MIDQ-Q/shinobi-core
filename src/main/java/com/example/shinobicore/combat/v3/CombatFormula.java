// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

/**
 * SPRINT 14 combat formula foundation.
 */
public final class CombatFormula {
    private CombatFormula() {}

    public static float calculateMeleeDamage(
            float baseDamage,
            float strengthLevel,
            float taijutsuLevel,
            float comboMultiplier
    ) {
        return baseDamage
                * (1.0f + strengthLevel * 0.02f + taijutsuLevel * 0.03f)
                * comboMultiplier;
    }
}