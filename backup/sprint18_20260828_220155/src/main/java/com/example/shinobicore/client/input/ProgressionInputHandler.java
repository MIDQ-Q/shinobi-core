// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.client.input;

import com.example.shinobicore.client.gui.screen.ProgressionV3Screen;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 13 progression key handler.
 * Opens ProgressionV3Screen with K key.
 */
public final class ProgressionInputHandler {
    private static boolean registered = false;
    private static boolean wasPressed = false;

    private ProgressionInputHandler() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;
        ClientTickEvents.END_CLIENT_TICK.register(ProgressionInputHandler::tick);
    }

    private static void tick(MinecraftClient client) {
        KeyBinding key = KeyBindings.PROGRESSION;

        boolean pressed = key != null && key.isPressed();

        if (pressed && !wasPressed) {
            if (client != null && client.player != null && client.currentScreen == null) {
                client.setScreen(new ProgressionV3Screen());
            }
        }

        wasPressed = pressed;
    }
}