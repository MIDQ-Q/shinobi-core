// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

import net.fabricmc.loader.api.FabricLoader;

/**
 * SPRINT 14 combat compatibility checker.
 */
public final class CombatCompatibilityChecker {
    private static boolean betterCombat = false;
    private static boolean playerAnimator = false;
    private static boolean geckoLib = false;
    private static boolean clothConfig = false;

    private CombatCompatibilityChecker() {}

    public static void init() {
        FabricLoader loader = FabricLoader.getInstance();

        betterCombat = loader.isModLoaded("bettercombat");
        playerAnimator = loader.isModLoaded("player-animator");
        geckoLib = loader.isModLoaded("geckolib");
        clothConfig = loader.isModLoaded("cloth-config");
    }

    public static boolean hasBetterCombat() {
        return betterCombat;
    }

    public static boolean hasPlayerAnimator() {
        return playerAnimator;
    }

    public static boolean hasGeckoLib() {
        return geckoLib;
    }

    public static boolean hasClothConfig() {
        return clothConfig;
    }

    public static String getReport() {
        return "BetterCombat=" + betterCombat +
                ", PlayerAnimator=" + playerAnimator +
                ", GeckoLib=" + geckoLib +
                ", ClothConfig=" + clothConfig;
    }
}