package com.example.shinobicore.modules.movement.client.input;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public final class MovementKeyBindings {
    public static KeyBinding ROLL_KEY;
    public static KeyBinding DODGE_KEY;
    public static KeyBinding CRAWL_KEY;

    private MovementKeyBindings() {}

    public static void register() {
        ROLL_KEY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.movement.roll", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, "category.shinobicore.movement"));
        DODGE_KEY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.movement.dodge", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_LEFT_ALT, "category.shinobicore.movement"));
        CRAWL_KEY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.movement.crawl", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_N, "category.shinobicore.movement"));
            
        ShinobiLogger.module("movement", "Keybindings registered.");
    }
}