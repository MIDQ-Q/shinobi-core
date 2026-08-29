// SHINOBICORE INDEPENDENT MOVEMENT LOGGER BOOTSTRAP
// Initializes logger and registers service WITHOUT modifying existing files.
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.util.MovementLogger;
import com.example.shinobicore.movement.client.MovementLoggerService;
import com.example.shinobicore.config.FeatureFlags;
import net.fabricmc.api.ClientModInitializer;

/**
 * Independent movement logger bootstrap.
 * Initializes logger and registers service.
 * Does NOT modify any existing movement files.
 */
public class MovementLoggerBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        MovementLogger.init();
        
        if (FeatureFlags.movementV3) {
            MovementLoggerService.register();
        }
    }
}