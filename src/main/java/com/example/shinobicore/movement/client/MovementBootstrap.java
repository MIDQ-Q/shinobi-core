package com.example.shinobicore.movement.client;

import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.util.ShinobiLogger;

public class MovementBootstrap implements ClientModInitializer {
    private static KeyBinding chakraKey;
    private static KeyBinding meditateKey;

    @Override
    public void onInitializeClient() {
        ShinobiLogger.info("[Movement] MovementBootstrap initializing...");
        
        chakraKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.chakra_v3", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_LEFT_SHIFT, "category.shinobicore"));
            
        meditateKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.meditate_v3", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, "category.shinobicore"));

        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (client.player == null || client.world == null) return;
            
            // Tick all movement modules
            ClientMovementService.tick(client);
            
            // Handle Chakra Mode Toggle
            while (chakraKey.wasPressed()) {
                ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
                ShinobiLogger.info("[Movement] Chakra Mode: " + ClientNinjaState.chakraMode);
            }
            
            // Handle Meditation Toggle
            while (meditateKey.wasPressed()) {
                MeditationClient.toggle(client.player);
                ShinobiLogger.info("[Movement] Meditation toggled");
            }
        });
        
        ShinobiLogger.info("[Movement] MovementBootstrap initialized successfully!");
    }
}