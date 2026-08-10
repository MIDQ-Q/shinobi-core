package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public class KeyBindings {
    public static final String CATEGORY = "key.categories.shinobicore";
    public static final String COMBAT_CATEGORY = "key.categories.shinobicore.combat";

    public static KeyBinding MEDITATE;
    public static KeyBinding CAST_A;
    public static KeyBinding CAST_B;
    public static KeyBinding CYCLE_A;
    public static KeyBinding CYCLE_B;
    public static KeyBinding PROGRESSION;
    public static KeyBinding CHAKRA_MODE;
    public static KeyBinding DODGE_LEFT;
    public static KeyBinding DODGE_RIGHT;
    public static KeyBinding CRAWL;
    public static KeyBinding KICK;

    public static void register() {
        // === Основное ===
        MEDITATE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.meditate", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, CATEGORY));
        PROGRESSION = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.progression", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_K, CATEGORY));
        CHAKRA_MODE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.chakra_mode", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_L, CATEGORY));

        // === Техники ===
        CAST_A = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cast", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, CATEGORY));
        CAST_B = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cast_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_T, CATEGORY));
        CYCLE_A = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cycle_slot", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_G, CATEGORY));
        CYCLE_B = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cycle_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_H, CATEGORY));

        // === Паркур ===
        DODGE_LEFT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.dodge_left", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Z, CATEGORY));
        DODGE_RIGHT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.dodge_right", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_C, CATEGORY));
        CRAWL = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.crawl", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_N, CATEGORY));

        // === Бой (F вместо Q чтобы не конфликтовать с drop item) ===
        KICK = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.kick", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, COMBAT_CATEGORY));
    }
}