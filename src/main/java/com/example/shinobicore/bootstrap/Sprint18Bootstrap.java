// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.progression.v3.ProgressionV3ServerHandler;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 18 server-side bootstrap.
 */
public class Sprint18Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) {
            return;
        }

        initialized = true;

        try {
            if (FeatureFlags.progression) {
                ProgressionV3ServerHandler.register();
                ShinobiLogger.info("[SPRINT18] Progression server handler registered");
            }
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT18] Bootstrap failed: " + t.getMessage());
        }
    }
}