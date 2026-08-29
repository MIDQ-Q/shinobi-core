// SHINOBICORE INDEPENDENT MOVEMENT LOGGER SERVICE
// This service reads state through public APIs ONLY.
// It does NOT modify any existing movement files.
package com.example.shinobicore.movement.client;

import com.example.shinobicore.util.MovementLogger;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

/**
 * Independent movement logger service.
 * Subscribes to client ticks and reads state via public APIs.
 * Does NOT modify any existing movement code.
 */
public final class MovementLoggerService {
    private static boolean registered = false;
    
    // State tracking for change detection
    private static String lastPhase = "NORMAL";
    private static boolean lastChakraMode = false;
    private static float lastChakra = -1.0f;
    private static double lastY = Double.NaN;
    private static double lastVy = Double.NaN;
    
    private MovementLoggerService() {}
    
    public static void register() {
        if (registered) return;
        registered = true;
        
        ClientTickEvents.END_CLIENT_TICK.register(MovementLoggerService::tickClient);
        MovementLogger.event("LOGGER", "MovementLoggerService registered");
    }
    
    private static void tickClient(MinecraftClient client) {
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;
        
        ClientPlayerEntity player = client.player;
        
        // Read current state via public APIs
        String currentPhase = getCurrentPhase();
        boolean currentChakraMode = getChakraMode();
        float currentChakra = getChakra();
        double currentY = player.getY();
        double currentVy = player.getVelocity().y;
        
        // Detect phase changes
        if (!currentPhase.equals(lastPhase)) {
            MovementLogger.stateChange(lastPhase, currentPhase, "detected via public API");
            lastPhase = currentPhase;
        }
        
        // Detect chakra mode changes
        if (currentChakraMode != lastChakraMode) {
            MovementLogger.event("CHAKRA", "Mode changed: " + (currentChakraMode ? "ON" : "OFF"));
            lastChakraMode = currentChakraMode;
        }
        
        // Detect large chakra changes
        if (lastChakra >= 0 && Math.abs(currentChakra - lastChakra) > 50.0f) {
            MovementLogger.warn("CHAKRA", String.format("Large chakra change: %.0f -> %.0f (delta=%.0f)",
                    lastChakra, currentChakra, currentChakra - lastChakra));
        }
        lastChakra = currentChakra;
        
        // Detect position jumps (potential teleports)
        if (!Double.isNaN(lastY)) {
            double deltaY = Math.abs(currentY - lastY);
            if (deltaY > 1.5 && Math.abs(currentVy) < 0.1) {
                MovementLogger.positionJump("TICK", lastY, currentY);
            }
        }
        
        // Detect velocity anomalies
        if (!Double.isNaN(lastVy)) {
            double deltaVy = Math.abs(currentVy - lastVy);
            if (deltaVy > 0.8) {
                MovementLogger.velocityCheck("TICK", lastVy, currentVy);
            }
        }
        
        lastY = currentY;
        lastVy = currentVy;
        
        // Periodic tick logging
        MovementLogger.tick(
            currentPhase,
            player.getX(), player.getY(), player.getZ(),
            player.getVelocity().x, player.getVelocity().y, player.getVelocity().z,
            player.isOnGround()
        );
    }
    
    // ========================================
    // Read state via public APIs (no modification)
    // ========================================
    
    private static String getCurrentPhase() {
        try {
            return ClientMovementState.getPhase().name();
        } catch (Throwable ignored) {
            return "UNKNOWN";
        }
    }
    
    private static boolean getChakraMode() {
        try {
            return com.example.shinobicore.chakra.client.ChakraClientController.isChakraModeActive();
        } catch (Throwable ignored) {
            return false;
        }
    }
    
    private static float getChakra() {
        try {
            return com.example.shinobicore.chakra.client.ChakraClientController.getCurrentChakra();
        } catch (Throwable ignored) {
            return 0.0f;
        }
    }
}