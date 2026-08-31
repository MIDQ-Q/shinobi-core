package com.example.shinobicore.modules.jutsu.client;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public final class JutsuKeyBindings {
    public static KeyBinding SLOT_A;
    public static KeyBinding SLOT_B;
    public static KeyBinding SLOT_C;
    public static KeyBinding CYCLE_SLOT;
    public static KeyBinding CAST_JUTSU;
    public static KeyBinding CANCEL_CAST;

    public static void register() {
        String category = "key.categories.shinobicore.jutsu";
        
        SLOT_A = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.slot_a", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Z, category));
        SLOT_B = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.slot_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_X, category));
        SLOT_C = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.slot_c", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_C, category));
        CYCLE_SLOT = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.cycle", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, category));
        
        CAST_JUTSU = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.cast", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_RIGHT_SHIFT, category));
        CANCEL_CAST = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.cancel", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_LEFT_SHIFT, category));
    }
}