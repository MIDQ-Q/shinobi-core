package com.example.shinobicore.modules.combat.input;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public final class CombatKeyBindings {
    public static KeyBinding stanceToggle;
    public static KeyBinding kick;
    public static KeyBinding sheathToggle;
    public static KeyBinding quickSlot;

    public static void register() {
        stanceToggle = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.combat.stance", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, "category.shinobicore.combat"));
        
        kick = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.combat.kick", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_F, "category.shinobicore.combat"));
            
        sheathToggle = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.combat.sheath", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_H, "category.shinobicore.combat"));
            
        quickSlot = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.combat.quickslot", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, "category.shinobicore.combat"));
    }
}