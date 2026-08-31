package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.client.anim.ParkourAnimationController;
import com.example.shinobicore.modules.movement.client.input.MovementInputHandler;
import net.minecraft.client.MinecraftClient;

public final class ClientMovementController {
    private static CoreEvents events;
    private static int tickCount = 0;
    private static int errorCount = 0;
    private static boolean firstTickLogged = false;

    private ClientMovementController() {}

    public static void init(CoreEvents eventsIn) {
        events = eventsIn;
        tickCount = 0;
        errorCount = 0;
        firstTickLogged = false;
        ShinobiLogger.module("movement", "Client controller initialized.");
    }

    public static CoreEvents events() {
        if (events == null) throw new IllegalStateException("ClientMovementController not initialized!");
        return events;
    }

    public static void tick() {
        MinecraftClient client = MinecraftClient.getInstance();

        // === AGGRESSIVE NULL GUARD ===
        if (client == null) {
            resetAll();
            return;
        }
        if (client.player == null) {
            if (tickCount > 0) {
                ShinobiLogger.module("movement", "Player became null, resetting all services.");
            }
            resetAll();
            return;
        }
        if (client.world == null) {
            if (tickCount > 0) {
                ShinobiLogger.module("movement", "World became null, resetting all services.");
            }
            resetAll();
            return;
        }

        tickCount++;

        // Log first successful tick
        if (!firstTickLogged) {
            firstTickLogged = true;
            ShinobiLogger.module("movement", "First successful client tick! Player="
                + client.player.getName().getString());
        }

        // Periodic health log every 200 ticks (10 seconds)
        if (tickCount % 200 == 0) {
            ShinobiLogger.module("movement", "Movement tick health: ticks=" + tickCount
                + " errors=" + errorCount
                + " player=" + client.player.getName().getString()
                + " pos=[" + String.format("%.1f,%.1f,%.1f",
                    client.player.getX(), client.player.getY(), client.player.getZ()) + "]");
        }

        try {
            ClientMovementState.tickCooldowns();
            MovementInputHandler.handleInput(client);

            WaterWalkService.tick(client.player);
            WallRunService.tick(client.player);
            SlideService.tick(client.player);
            CrawlService.tick(client.player);
            RollService.tick(client.player);
            DodgeService.tick(client.player);
            DoubleJumpService.resetOnGround(client.player);
            ChargedJumpService.tickCharge(client.player);
            EdgeGrabService.tick(client.player);
            ParkourAnimationController.tick(client.player);

        } catch (Throwable t) {
            errorCount++;
            if (errorCount <= 10) {
                // Log first 10 errors, then stop spamming
                ShinobiLogger.error("movement", "Tick error #" + errorCount + ": " + t.getMessage(), t);
            } else if (errorCount == 11) {
                ShinobiLogger.error("movement", "Suppressing further tick errors (total so far: " + errorCount + ")", null);
            }
        }
    }

    private static void resetAll() {
        tickCount = 0;
        ClientMovementState.reset();
        WallRunService.reset();
    }

    public static int getTickCount() { return tickCount; }
    public static int getErrorCount() { return errorCount; }
}