// SHINOBICORE:SPRINT13/14:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.client.input.ProgressionInputHandler;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 13/14 client-side bootstrap.
 */
public class Sprint1314ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        try {
            if (FeatureFlags.progression) {
                ProgressionInputHandler.register();
                ShinobiLogger.info("[SPRINT13] Progression input handler registered (K opens screen)");
            }
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT13/14] Client bootstrap failed: " + t.getMessage());
        }
    }
}