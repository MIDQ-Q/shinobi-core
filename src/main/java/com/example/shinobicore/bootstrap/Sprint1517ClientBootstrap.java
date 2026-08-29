// SHINOBICORE:SPRINT15-17:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.client.network.ProgressionV3ClientSync;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 15/16/17 client-side bootstrap.
 */
public class Sprint1517ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        try {
            if (FeatureFlags.progression) {
                ProgressionV3ClientSync.register();
                ShinobiLogger.info("[SPRINT15] Progression client sync registered");
            }
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT15-17] Client bootstrap failed: " + t.getMessage());
        }
    }
}