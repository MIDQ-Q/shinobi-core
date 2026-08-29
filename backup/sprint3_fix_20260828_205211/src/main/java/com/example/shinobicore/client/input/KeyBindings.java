package com.example.shinobicore.client.input;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

/**
* Key bindings. SPRINT B adds PROGRESSION (K) which opens the progression hub.
*/
public final class KeyBindings {
    private KeyBindings() {}

    public static KeyBinding ROLL;
    public static KeyBinding DODGE_LEFT;
    public static KeyBinding DODGE_RIGHT;
    public static KeyBinding MEDITATE;
    public static KeyBinding PROGRESSION;

    public static void register() {
        ROLL = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.roll",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_R,
                "key.categories.shinobicore.movement"
        ));
        DODGE_LEFT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.dodge_left",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_Q,
                "key.categories.shinobicore.movement"
        ));
        DODGE_RIGHT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.dodge_right",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_E,
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
                "key.categories.shinobicore.ui"
        ));

        // Register the progression screen input handler
        ProgressionInputHandler.register();
    }
}