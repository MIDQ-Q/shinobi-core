// SHINOBICORE:SPRINT17:FILE
package com.example.shinobicore.combat.v3.adapter;

import com.example.shinobicore.util.ShinobiLogger;

/**
 * SPRINT 17 combat adapter manager.
 */
public final class CombatAdapterManager {
    private static boolean initialized = false;

    private CombatAdapterManager() {}

    public static void init() {
        if (initialized) {
            return;
        }

        initialized = true;

        BetterCombatAdapter.init();
        PlayerAnimatorAdapter.init();
        GeckoLibAdapter.init();
        ClothConfigAdapter.init();

        ShinobiLogger.info("[COMBAT-V3] Adapters: " + getReport());
    }

    public static String getReport() {
        return "BetterCombat=" + BetterCombatAdapter.getStatus()
                + ", PlayerAnimator=" + PlayerAnimatorAdapter.getStatus()
                + ", GeckoLib=" + GeckoLibAdapter.getStatus()
                + ", ClothConfig=" + ClothConfigAdapter.getStatus();
    }
}