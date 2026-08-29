// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.client.ClientMovementService;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 4 client-side bootstrap.
 * Registers movement services and subsystems.
 */
public class Sprint4ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.movementV3) {
            ShinobiLogger.info("[SPRINT4] movementV3 flag disabled, skipping client bootstrap");
            return;
        }

        ClientMovementService.register();
        ShinobiLogger.info("[SPRINT4] Client movement service registered (Water Walk foundation)");
    }
}