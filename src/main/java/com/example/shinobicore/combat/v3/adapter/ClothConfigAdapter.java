// SHINOBICORE:SPRINT17:FILE
package com.example.shinobicore.combat.v3.adapter;

import net.fabricmc.loader.api.FabricLoader;

/**
 * SPRINT 17 Cloth Config adapter foundation.
 */
public final class ClothConfigAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    private ClothConfigAdapter() {}

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("cloth-config")) {
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