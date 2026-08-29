// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;

/**
 * SPRINT 14 combat module foundation.
 */
public final class CombatV3Module {
    private static boolean initialized = false;

    private CombatV3Module() {}

    public static void init() {
        if (!FeatureFlags.combatV3) {
            ShinobiLogger.info("[COMBAT-V3] disabled by flag");
            return;
        }

        if (initialized) {
            return;
        }

        initialized = true;

        CombatCompatibilityChecker.init();
        CombatV3Commands.register();

        ShinobiLogger.info("[COMBAT-V3] Foundation initialized");
        ShinobiLogger.info("[COMBAT-V3] " + CombatCompatibilityChecker.getReport());
    }

    public static boolean isInitialized() {
        return initialized;
    }
}