package com.example.shinobicore.combat;

import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.ICombatComponent;
import com.example.shinobicore.stat.component.IStatsComponent;

/**
 * Centralized balance formulas (HLD 2.6, 4.5, 4.6).
 * Layer model: EF base damage * NinjaFormula multipliers.
 */
public final class NinjaFormula {

    private NinjaFormula() {}

    /**
     * Melee damage multiplier:
     * (1 + taijutsu * 0.005) * stanceMult * fatiguePenalty.
     * HLD 4.6: 75-99 fatigue = 0.75x, 100 = 0x.
     */
    public static float getMeleeMultiplier(IStatsComponent stats, ICombatComponent combat, IChakraComponent chakra) {
        float tai = stats.getStatLevel(StatType.TAIJUTSU);
        float base = 1.0f + tai * 0.005f;

        Stance stance = Stance.fromId(combat.getStanceId());
        float stanceMult = stance.getDamageMult();

        float fatigue = chakra.getFatigue();
        float fatigueMult = 1.0f;
        if (fatigue >= 100.0f) {
            fatigueMult = 0.0f;
        } else if (fatigue >= 75.0f) {
            fatigueMult = 0.75f;
        }

        return base * stanceMult * fatigueMult;
    }

    /**
     * Jutsu cost multiplier (control reduces cost, up to -50%).
     * HLD 2.6.
     */
    public static float getJutsuCostMultiplier(IStatsComponent stats) {
        float control = stats.getStatLevel(StatType.CONTROL);
        float reduction = Math.min(0.5f, control * 0.005f);
        return 1.0f - reduction;
    }

    /**
     * Jutsu damage multiplier (ninjutsu scaling, up to +100%).
     * HLD 2.6.
     */
    public static float getJutsuDamageMultiplier(IStatsComponent stats) {
        float nin = stats.getStatLevel(StatType.NINJUTSU);
        return 1.0f + nin * 0.01f;
    }

    /**
     * Fatigue penalty for casting (HLD 4.6).
     */
    public static float getFatigueCastPenalty(IChakraComponent chakra) {
        float fatigue = chakra.getFatigue();
        if (fatigue >= 100.0f) {
            return 0.0f;
        }
        if (fatigue >= 75.0f) {
            return 0.75f;
        }
        return 1.0f;
    }
}