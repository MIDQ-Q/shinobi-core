package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public class KeyBindings {
    public static final String CATEGORY = "key.categories.shinobicore";

    public static KeyBinding MEDITATE;
    public static KeyBinding CAST_A;
    public static KeyBinding CAST_B;
    public static KeyBinding CYCLE_A;
    public static KeyBinding CYCLE_B;
    public static KeyBinding PROGRESSION;
    public static KeyBinding CHAKRA_MODE;

    public static void register() {
        MEDITATE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.meditate", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, CATEGORY));
        CAST_A = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cast", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, CATEGORY));
        CAST_B = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cast_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_T, CATEGORY));
        CYCLE_A = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cycle_slot", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_G, CATEGORY));
        CYCLE_B = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cycle_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_H, CATEGORY));
        PROGRESSION = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.progression", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_K, CATEGORY));
        CHAKRA_MODE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.chakra_mode", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_L, CATEGORY));
    }
}