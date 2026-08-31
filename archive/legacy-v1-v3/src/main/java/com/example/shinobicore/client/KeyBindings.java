// SHINOBICORE:SPRINT3-FIX:FILE
package com.example.shinobicore.client;

import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 3 legacy compatibility wrapper.
 * Delegates registration to client.input.KeyBindings.
 */
public final class KeyBindings {
    private KeyBindings() {}

    public static KeyBinding CHAKRA_MODE;
    public static KeyBinding ROLL;
    public static KeyBinding DODGE_LEFT;
    public static KeyBinding DODGE_RIGHT;
    public static KeyBinding MEDITATE;
    public static KeyBinding PROGRESSION;
    public static KeyBinding CRAWL;

    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;

        com.example.shinobicore.client.input.KeyBindings.register();

        CHAKRA_MODE = com.example.shinobicore.client.input.KeyBindings.CHAKRA_MODE;
        ROLL = com.example.shinobicore.client.input.KeyBindings.ROLL;
        DODGE_LEFT = com.example.shinobicore.client.input.KeyBindings.DODGE_LEFT;
        DODGE_RIGHT = com.example.shinobicore.client.input.KeyBindings.DODGE_RIGHT;
        MEDITATE = com.example.shinobicore.client.input.KeyBindings.MEDITATE;
        PROGRESSION = com.example.shinobicore.client.input.KeyBindings.PROGRESSION;
        CRAWL = com.example.shinobicore.client.input.KeyBindings.CRAWL;
    }

    public static void init() {
        register();
    }
}