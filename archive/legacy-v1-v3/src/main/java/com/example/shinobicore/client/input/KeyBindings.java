// SHINOBICORE:SPRINT3-FINAL:FILE
package com.example.shinobicore.client.input;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

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

        CHAKRA_MODE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.chakra_mode",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_L,
                "key.categories.shinobicore"
        ));

        ROLL = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.roll",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_R,
                "key.categories.shinobicore.movement"
        ));

        DODGE_LEFT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.dodge_left",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_Z,
                "key.categories.shinobicore.movement"
        ));

        DODGE_RIGHT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.dodge_right",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_C,
                "key.categories.shinobicore.movement"
        ));

        MEDITATE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.meditate",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_M,
                "key.categories.shinobicore.movement"
        ));

        PROGRESSION = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.progression",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_K,
                "key.categories.shinobicore"
        ));

        CRAWL = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.crawl",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_N,
                "key.categories.shinobicore.movement"
        ));
    }
}