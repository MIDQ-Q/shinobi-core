package com.example.shinobicore.modules.combat.compat;

import net.fabricmc.loader.api.FabricLoader;

public final class CombatCompatibilityChecker {
    private CombatCompatibilityChecker() {}
    public static boolean isBetterCombatOk() {
        return FabricLoader.getInstance().isModLoaded("bettercombat");
    }
}