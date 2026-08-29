// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;

/**
 * SPRINT 4 central client movement tick handler.
 */
public final class ClientMovementService {
    private static boolean registered = false;

    private ClientMovementService() {}

    public static void register() {
        if (registered) return;
        registered = true;
        ClientTickEvents.END_CLIENT_TICK.register(ClientMovementService::tickClient);
    }

    private static void tickClient(MinecraftClient client) {
        if (!FeatureFlags.movementV3) return;
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;

        // Update state timers
        ClientMovementState.tick();

        // Tick subsystems
        WaterWalkClient.tick(client.player);
        // Future: WallRunClient.tick(...), SlideClient.tick(...), etc.

        // If no subsystem is active, reset phase to NORMAL
        if (!WaterWalkClient.isActive()) {
            if (ClientMovementState.getPhase() != MovementPhase.NORMAL) {
                ClientMovementState.setPhase(MovementPhase.NORMAL);
            }
        }
    }
}