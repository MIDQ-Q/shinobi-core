package com.example.shinobicore;

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

        ShinobiLogger.info("=== ShinobiCore Client Initialized ===");
    }
}