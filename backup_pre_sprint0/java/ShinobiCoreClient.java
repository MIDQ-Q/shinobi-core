package com.example.shinobicore;

import com.example.shinobicore.network.ModPackets;
import net.fabricmc.api.ClientModInitializer;
import com.example.shinobicore.util.DebugTraceLogger;

/**
 * Client entrypoint for ShinobiCore v2.0.
 * HLD: Section 1.2 (Network)
 */
public class ShinobiCoreClient implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        ShinobiCore.LOGGER.info("Initializing ShinobiCore Client v2.0...");
        DebugTraceLogger.init();
        ModPackets.registerClient();

        // Sprint 1: entity renderers (HLD Section 2.4)
        com.example.shinobicore.client.render.ModRenderers.init();

        // Sprint 2: keybindings and magnetic boots client (HLD 4.2)
        com.example.shinobicore.client.KeyBindings.init();
        com.example.shinobicore.client.hud.ShinobiHud.init();
        // WallRunClient removed - replaced by WallWalkPhysics (Stage 1)
        com.example.shinobicore.client.parkour.ParkourClientHandler.init();
        com.example.shinobicore.client.ChakraPhysicsClient.register();
        com.example.shinobicore.client.render.EnemyRenderers.init();

        // Sprint 3: GeckoLib enemy renderers (HLD Section 5)
        com.example.shinobicore.client.render.EnemyRenderers.init();
    }
}