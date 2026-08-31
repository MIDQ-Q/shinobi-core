package com.example.shinobicore;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;
import com.example.shinobicore.movement.client.ClientMovementService;
import com.example.shinobicore.movement.client.MeditationClient;
import com.example.shinobicore.client.ClientNinjaState;

import com.example.shinobicore.client.render.ShinobiAnimationController;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

public class ShinobiCoreClient implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        ShinobiLogger.info("=== ShinobiCore Client Starting ===");

        // Animation controller
        ShinobiAnimationController.init();

        // SHINOBICORE:MOVEMENT_V3:BEGIN
        // Packet registration (must be before ClientChakraController)
        com.example.shinobicore.network.ModPackets.registerClient();
        // Chakra controller (client-authoritative)
        com.example.shinobicore.chakra.client.ClientChakraController.register();
        // Movement system (client-authoritative)
// [SPRINT3-QUARANTINE] com.example.shinobicore.movement.client.ClientMovementService.register();
        // Key bindings
        com.example.shinobicore.client.input.KeyBindings.register();
        // SHINOBICORE:MOVEMENT_V3:END

        
        // === MOVEMENT & KEYBINDINGS INJECTION ===
        KeyBinding chakraKey = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.chakra_v3", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_LEFT_SHIFT, "category.shinobicore"));
        KeyBinding meditateKey = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.meditate_v3", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, "category.shinobicore"));

        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (client.player == null) return;
            
            // Tick all movement modules
            ClientMovementService.tick(client);
            
            // Handle Chakra Mode Toggle
            while (chakraKey.wasPressed()) {
                ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
                // TODO: Send packet to server to sync chakra mode state
            }
            
            // Handle Meditation Toggle
            while (meditateKey.wasPressed()) {
                MeditationClient.toggle(client.player);
            }
        });
        // ==========================================
        ShinobiLogger.info("=== ShinobiCore Client Initialized ===");
    }
}