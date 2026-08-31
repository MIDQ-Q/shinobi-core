package com.example.shinobicore.modules.progression.client;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public final class ProgressionKeyBindings {
    public static KeyBinding OPEN_PROGRESSION_KEY;

    private ProgressionKeyBindings() {}

    public static void register() {
        OPEN_PROGRESSION_KEY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.progression.open",
            InputUtil.Type.KEYSYM,
            GLFW.GLFW_KEY_K,
            "category.shinobicore.progression"
        ));
    }
}