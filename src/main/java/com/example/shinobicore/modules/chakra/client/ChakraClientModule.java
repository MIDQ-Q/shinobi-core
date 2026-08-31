package com.example.shinobicore.modules.chakra.client;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public final class ChakraClientModule implements ClientAwareModule {
    public static final String ID = "chakra_client";
    private static KeyBinding CHAKRA_TOGGLE;

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        // No server-side registration needed
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        // No server-side enable needed
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        CHAKRA_TOGGLE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.chakra_toggle",
            InputUtil.Type.KEYSYM,
            GLFW.GLFW_KEY_L,
            "category.shinobicore.chakra"
        ));

        ChakraHudRenderer.register();

        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (client.player == null) return;
            if (CHAKRA_TOGGLE.wasPressed()) {
                client.player.networkHandler.sendCommand("shinobicore chakra toggle");
            }
        });

        ShinobiLogger.module(ID, "Chakra client initialized. Press L to toggle.");
    }
}