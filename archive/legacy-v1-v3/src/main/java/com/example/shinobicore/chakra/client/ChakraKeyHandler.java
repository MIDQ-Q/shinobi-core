// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.chakra.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 3 key handler for Chakra Mode (L key).
 * Uses reflection to safely access legacy KeyBindings.CHAKRA_MODE.
 */
public final class ChakraKeyHandler {
    private static boolean registered = false;
    private static boolean wasPressed = false;

    private ChakraKeyHandler() {}

    public static void register() {
        if (registered) return;
        registered = true;
        ClientTickEvents.END_CLIENT_TICK.register(ChakraKeyHandler::tick);
        ShinobiLogger.info("[SPRINT3] ChakraKeyHandler registered");
    }

    private static void tick(MinecraftClient client) {
        // [AUTO-FIX] if (!FeatureFlags.chakraV3) return;
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;
        if (client.currentScreen != null) return;

        KeyBinding chakraKey = resolveChakraKey();
        if (chakraKey == null) return;

        boolean pressed = chakraKey.isPressed();
        if (pressed && !wasPressed) {
            ChakraClientController.toggleChakraMode();
            if (ChakraClientController.isChakraModeActive()) {
                ShinobiLogger.info("[CHAKRA] Mode ON (L pressed)");
            } else {
                ShinobiLogger.info("[CHAKRA] Mode OFF (L pressed)");
            }
        }
        wasPressed = pressed;
    }

    private static KeyBinding resolveChakraKey() {
        try {
            Class<?> kbClass = Class.forName("com.example.shinobicore.client.KeyBindings");
            Object value = kbClass.getField("CHAKRA_MODE").get(null);
            if (value instanceof KeyBinding) return (KeyBinding) value;
        } catch (Throwable ignored) {}

        try {
            Class<?> kbClass = Class.forName("com.example.shinobicore.client.input.KeyBindings");
            Object value = kbClass.getField("CHAKRA_MODE").get(null);
            if (value instanceof KeyBinding) return (KeyBinding) value;
        } catch (Throwable ignored) {}

        return null;
    }
}