// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.command.MovementCommands;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;

/**
 * SPRINT 3 server-side bootstrap.
 * Registers movement commands and future parkour systems.
 */
public class Sprint3Bootstrap implements ModInitializer {
    private static boolean initialized = false;

    @Override
    public void onInitialize() {
        if (initialized) return;
        initialized = true;

        try {
            if (!FeatureFlags.movementV3) {
                ShinobiLogger.info("[SPRINT3] movementV3 flag disabled, skipping bootstrap");
                return;
            }

            MovementCommands.register();
            ShinobiLogger.info("[SPRINT3] Movement foundation bootstrap initialized");
        } catch (Throwable t) {
            ShinobiLogger.error("[SPRINT3] Bootstrap failed: " + t.getMessage());
        }
    }
}