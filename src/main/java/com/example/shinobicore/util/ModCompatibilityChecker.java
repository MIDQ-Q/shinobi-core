package com.example.shinobicore.util;

import net.fabricmc.loader.api.FabricLoader;
import java.util.ArrayList;
import java.util.List;

public final class ModCompatibilityChecker {
    private ModCompatibilityChecker() {}

    public record ModCheck(String modId, String name, boolean required, boolean present) {}
    private static final List<ModCheck> CHECKS = new ArrayList<>();

    public static void init() {
        ShinobiLogger.info("=== MOD COMPATIBILITY CHECK ===");
        check("fabric-api", "Fabric API", true);
        check("cardinal-components-base", "Cardinal Components Base", true);
        check("cardinal-components-entity", "Cardinal Components Entity", true);
        check("bettercombat", "Better Combat", false);
        check("geckolib", "GeckoLib", false);
        check("cloth-config", "Cloth Config", false);
        check("player-animator", "Player Animator", false);

        int present = 0;
        int total = CHECKS.size();
        for (ModCheck c : CHECKS) {
            String status = c.present() ? "[OK]" : (c.required() ? "[MISSING!]" : "[OPTIONAL]");
            ShinobiLogger.info("  %s %s (%s)", status, c.name(), c.modId());
            if (c.present()) present++;
        }
        ShinobiLogger.info("=== RESULT: %d/%d mods loaded ===", present, total);

        for (ModCheck c : CHECKS) {
            if (c.required() && !c.present()) {
                String msg = String.format("FATAL: Required mod '%s' (%s) is NOT installed!", c.name(), c.modId());
                ShinobiLogger.fatal(msg);
                throw new RuntimeException(msg);
            }
        }

        if (!isPresent("bettercombat")) ShinobiLogger.warn("Better Combat not found! Melee combat will use fallback system.");
        if (!isPresent("geckolib")) ShinobiLogger.warn("GeckoLib not found! Custom mobs will be disabled.");
        if (!isPresent("player-animator")) ShinobiLogger.warn("Player Animator not found! Hand seals will use fallback poses.");
    }

    private static void check(String modId, String name, boolean required) {
        CHECKS.add(new ModCheck(modId, name, required, FabricLoader.getInstance().isModLoaded(modId)));
    }

    public static boolean isPresent(String modId) { return FabricLoader.getInstance().isModLoaded(modId); }
    public static boolean hasBetterCombat() { return isPresent("bettercombat"); }
    public static boolean hasGeckoLib() { return isPresent("geckolib"); }
    public static boolean hasPlayerAnimator() { return isPresent("player-animator"); }
    public static boolean hasClothConfig() { return isPresent("cloth-config"); }
}