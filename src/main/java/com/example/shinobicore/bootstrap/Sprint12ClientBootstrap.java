// SHINOBICORE:SPRINT12:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.command.MovementDebugCommand;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.client.MovementPhaseHud;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 12 client-side bootstrap.
 * Registers debug HUD and client commands.
 */
public class Sprint12ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.movementV3) return;

        MovementDebugCommand.register();
        MovementPhaseHud.register();

        ShinobiLogger.info("[SPRINT12] Debug command and HUD registered");
    }
}