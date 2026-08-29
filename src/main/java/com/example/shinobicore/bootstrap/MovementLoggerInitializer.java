// SHINOBICORE MOVEMENT LOGGER INITIALIZER
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.util.MovementLogger;
import net.fabricmc.api.ModInitializer;

/**
 * Initializes the movement logger.
 */
public class MovementLoggerInitializer implements ModInitializer {
    @Override
    public void onInitialize() {
        MovementLogger.init();
        MovementLogger.event("INIT", "Movement logger initialized");
    }
}