// SHINOBICORE:SPRINT17:FILE
package com.example.shinobicore.combat.v3.adapter;

import net.fabricmc.loader.api.FabricLoader;

/**
 * SPRINT 17 Player Animator adapter foundation.
 */
public final class PlayerAnimatorAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    private PlayerAnimatorAdapter() {}

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("player-animator")) {
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