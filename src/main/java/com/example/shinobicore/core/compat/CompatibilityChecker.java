package com.example.shinobicore.core.compat;
import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.loader.api.FabricLoader;
public final class CompatibilityChecker {
    private CompatibilityChecker() {}
    public static void check() {
        String[] required = { "fabric-api", "cardinal-components-base", "cardinal-components-entity" };
        String[] optional = { "bettercombat", "player-animator", "geckolib", "cloth-config" };
        for (String id : required) {
            if (!FabricLoader.getInstance().isModLoaded(id)) {
                ShinobiLogger.error("core", "MISSING REQUIRED MOD: " + id, null);
            } else {
                ShinobiLogger.core("Required mod present: " + id);
            }
        }
        for (String id : optional) {
            if (FabricLoader.getInstance().isModLoaded(id)) {
                ShinobiLogger.core("Optional mod present: " + id);
            } else {
                ShinobiLogger.core("Optional mod absent: " + id);
            }
        }
    }
}