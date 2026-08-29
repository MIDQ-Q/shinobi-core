// SHINOBICORE:SPRINT12:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;

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
        if (client.currentScreen != null) return;
        if (client.player.isDead()) return;

        ClientMovementState.tick();
        MovementInputService.update(client.player);
        RollDodgeInputHandler.update(client.player);

        if (MovementInputService.wasJumpPressed()) {
            ClientMovementState.setJumpGraceTicks(6);
        }

        WaterWalkClient.tick(client.player);
        WallRunClient.tick(client.player);
        RollClient.tick(client.player);
        DodgeClient.tick(client.player);
        SlideClient.tick(client.player);
        CrawlClient.tick(client.player);
        ChargedJumpClient.tick(client.player);
        DoubleJumpClient.tick(client.player);
        EdgeGrabClient.tick(client.player);
        MeditationClient.tick(client.player);

        if (!WaterWalkClient.isActive()
                && !WallRunClient.isActive()
                && !RollClient.isActive()
                && !DodgeClient.isActive()
                && !SlideClient.isActive()
                && !CrawlClient.isActive()
                && !ChargedJumpClient.isCharging()
                && !EdgeGrabClient.isActive()
                && !MeditationClient.isActive()) {
            if (ClientMovementState.getPhase() != MovementPhase.NORMAL) {
                ClientMovementState.setPhase(MovementPhase.NORMAL);
            }
        }
    }
}