// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.chakra.client.ChakraKeyHandler;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 3 client-side bootstrap.
 * Registers key handlers and future parkour client systems.
 */
public class Sprint3ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.movementV3) {
            ShinobiLogger.info("[SPRINT3] movementV3 flag disabled, skipping client bootstrap");
            return;
        }

        ChakraKeyHandler.register();
        ShinobiLogger.info("[SPRINT3] Client key handler registered (L = chakra mode toggle)");
    }
}