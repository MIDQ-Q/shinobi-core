package com.example.shinobicore.modules.clans.client;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;
public final class ClansKeyBindings {
    public static KeyBinding OPEN_CLAN_MENU;
    public static void register() {
        OPEN_CLAN_MENU = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.clan_menu",
            InputUtil.Type.KEYSYM,
            GLFW.GLFW_KEY_J,
            "category.shinobicore.clans"
        ));
    }
}