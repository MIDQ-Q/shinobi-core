// SHINOBICORE:SPRINT13/14:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.combat.v3.CombatV3Module;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.progression.v3.ProgressionV3Commands;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 13/14 server-side bootstrap.
 */
public class Sprint1314Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) {
            return;
        }

        initialized = true;

        try {
            if (FeatureFlags.progression) {
                ProgressionV3Commands.register();
                ShinobiLogger.info("[SPRINT13] Progression V3 commands registered");
            }

            CombatV3Module.init();

            ShinobiLogger.info("[SPRINT13/14] Progression + Combat foundation bootstrap complete");
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT13/14] Bootstrap failed: " + t.getMessage());
        }
    }
}