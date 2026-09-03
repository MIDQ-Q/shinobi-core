package com.example.shinobicore.compat;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.loader.api.FabricLoader;
import net.fabricmc.loader.api.ModContainer;

import java.util.Optional;

/**
 * Checks for required mod dependencies and their versions.
 * Provides clear error messages if dependencies are missing.
 */
public final class CompatibilityChecker {
    private static boolean betterCombatOk = false;
    private static boolean playerAnimatorOk = false;
    private static boolean geckoLibOk = false;
    private static boolean clothConfigOk = false;
    private static boolean cardinalComponentsOk = false;
    
    private CompatibilityChecker() {}
    
    /**
     * Initialize and check all dependencies.
     */
    public static void init() {
        ShinobiLogger.module("compat", "Checking dependencies...");
        
        betterCombatOk = checkMod("bettercombat", "Better Combat");
        playerAnimatorOk = checkMod("player-animator", "Player Animator");
        geckoLibOk = checkMod("geckolib", "GeckoLib");
        clothConfigOk = checkMod("cloth-config", "Cloth Config");
        cardinalComponentsOk = checkMod("cardinal-components-base", "Cardinal Components API");
        
        logStatus();
    }
    
    /**
     * Check if a mod is present.
     */
    private static boolean checkMod(String modId, String displayName) {
        Optional<ModContainer> mod = FabricLoader.getInstance().getModContainer(modId);
        if (mod.isPresent()) {
            String version = mod.get().getMetadata().getVersion().getFriendlyString();
            ShinobiLogger.module("compat", String.format("вњ“ %s found (v%s)", displayName, version));
            return true;
        } else {
            ShinobiLogger.module("compat", String.format("вњ— %s NOT FOUND - some features will be disabled", displayName));
            return false;
        }
    }
    
    /**
     * Log the status of all dependencies.
     */
    public static void logStatus() {
        ShinobiLogger.info("=== Dependency Status ===");
        ShinobiLogger.info("Better Combat: " + (betterCombatOk ? "OK" : "MISSING"));
        ShinobiLogger.info("Player Animator: " + (playerAnimatorOk ? "OK" : "MISSING"));
        ShinobiLogger.info("GeckoLib: " + (geckoLibOk ? "OK" : "MISSING"));
        ShinobiLogger.info("Cloth Config: " + (clothConfigOk ? "OK" : "MISSING"));
        ShinobiLogger.info("Cardinal Components: " + (cardinalComponentsOk ? "OK" : "MISSING"));
    }
    
    /**
     * Get a report of all dependencies.
     */
    public static String getReport() {
        StringBuilder sb = new StringBuilder();
        sb.append("Better Combat: ").append(betterCombatOk ? "OK" : "MISSING").append("\n");
        sb.append("Player Animator: ").append(playerAnimatorOk ? "OK" : "MISSING").append("\n");
        sb.append("GeckoLib: ").append(geckoLibOk ? "OK" : "MISSING").append("\n");
        sb.append("Cloth Config: ").append(clothConfigOk ? "OK" : "MISSING").append("\n");
        sb.append("Cardinal Components: ").append(cardinalComponentsOk ? "OK" : "MISSING");
        return sb.toString();
    }
    
    // === Getters ===
    
    public static boolean isBetterCombatOk() { return betterCombatOk; }
    public static boolean isPlayerAnimatorOk() { return playerAnimatorOk; }
    public static boolean isGeckoLibOk() { return geckoLibOk; }
    public static boolean isClothConfigOk() { return clothConfigOk; }
    public static boolean isCardinalComponentsOk() { return cardinalComponentsOk; }
    
    /**
     * Check if all critical dependencies are present.
     */
    public static boolean allCriticalOk() {
        return cardinalComponentsOk; // CCA is absolutely required
    }
}