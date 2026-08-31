// SHINOBICORE:SPRINT17:FILE
package com.example.shinobicore.combat.v3.adapter;

import net.fabricmc.loader.api.FabricLoader;

/**
 * SPRINT 17 Better Combat adapter foundation.
 */
public final class BetterCombatAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    private BetterCombatAdapter() {}

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("bettercombat")) {
            enabled = true;
            status = "loaded";
        } else {
            enabled = false;
            status = "not installed";
        }
    }

    public static boolean isEnabled() {
        return enabled;
    }

    public static String getStatus() {
        return status;
    }
}