// SHINOBICORE:SPRINT1:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.command.ChakraCommands;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 1 safe bootstrap.
 *
 * Registered as an additional main entrypoint.
 */
public class Sprint1Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) {
            return;
        }

        initialized = true;

        try {
            if (!FeatureFlags.chakraV3) {
                ShinobiLogger.info("[SPRINT1] chakraV3 flag disabled, skipping bootstrap");
                return;
            }

            if (FeatureFlags.chakraConfig) {
                MovementChakraConfig.load();
            }

            if (FeatureFlags.chakraCommands) {
                ChakraCommands.register();
            }

            ShinobiLogger.info("[SPRINT1] Chakra foundation bootstrap initialized");
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT1] Bootstrap failed: " + t.getMessage());
        }
    }
}