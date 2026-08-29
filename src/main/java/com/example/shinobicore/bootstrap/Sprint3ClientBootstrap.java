// SHINOBICORE:SPRINT3-FIX:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.chakra.client.ChakraKeyHandler;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 3 client-side bootstrap.
 * Registers key bindings and chakra key handler.
 */
public class Sprint3ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.movementV3) {
            ShinobiLogger.info("[SPRINT3] movementV3 flag disabled, skipping client bootstrap");
            return;
        }

        try {
            Class<?> inputKeys = Class.forName("com.example.shinobicore.client.input.KeyBindings");
            inputKeys.getMethod("register").invoke(null);
        } catch (Throwable ignored) {}

        try {
            Class<?> legacyKeys = Class.forName("com.example.shinobicore.client.KeyBindings");
            legacyKeys.getMethod("register").invoke(null);
        } catch (Throwable ignored) {}

        ChakraKeyHandler.register();
        ShinobiLogger.info("[SPRINT3] Client key handler registered (L = chakra mode toggle)");
    }
}