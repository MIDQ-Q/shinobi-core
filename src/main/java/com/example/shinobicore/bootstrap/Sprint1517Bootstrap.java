// SHINOBICORE:SPRINT15-17:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.combat.v3.adapter.CombatAdapterManager;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.event.XpSourceService;
import com.example.shinobicore.progression.v3.ProgressionJoinHandler;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 15/16/17 server-side bootstrap.
 */
public class Sprint1517Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) {
            return;
        }

        initialized = true;

        try {
            if (FeatureFlags.progression) {
                ProgressionJoinHandler.register();
                XpSourceService.register();
                ShinobiLogger.info("[SPRINT15/16] Progression sync + XP sources registered");
            }

            if (FeatureFlags.combatV3) {
                CombatAdapterManager.init();
                ShinobiLogger.info("[SPRINT17] Combat adapters initialized");
            }
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT15-17] Bootstrap failed: " + t.getMessage());
        }
    }
}