package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public class KeyBindings {
    public static final String CATEGORY = "key.categories.shinobicore";

    public static KeyBinding MEDITATE;
    public static KeyBinding CAST;
    public static KeyBinding CYCLE_SLOT;
    public static KeyBinding PROGRESSION;
    public static KeyBinding JUTSU_WHEEL;
    public static KeyBinding SLOT_1;
    public static KeyBinding SLOT_2;
    public static KeyBinding SLOT_3;
    public static KeyBinding SLOT_4;
    public static KeyBinding SLOT_5;
    public static KeyBinding CHAKRA_MODE;

    public static void register() {
        MEDITATE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.meditate", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, CATEGORY));

        CAST = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cast", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, CATEGORY));

        CYCLE_SLOT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cycle_slot", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_G, CATEGORY));

        PROGRESSION = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.progression", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_K, CATEGORY));

        JUTSU_WHEEL = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.jutsu_wheel", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, CATEGORY));
        CHAKRA_MODE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.chakra_mode", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_L, CATEGORY));
        SLOT_1 = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.slot1", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_UNKNOWN, CATEGORY));
        SLOT_2 = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.slot2", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_UNKNOWN, CATEGORY));
        SLOT_3 = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.slot3", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_UNKNOWN, CATEGORY));
        SLOT_4 = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.slot4", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_UNKNOWN, CATEGORY));
        SLOT_5 = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.slot5", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_UNKNOWN, CATEGORY));
    }
}