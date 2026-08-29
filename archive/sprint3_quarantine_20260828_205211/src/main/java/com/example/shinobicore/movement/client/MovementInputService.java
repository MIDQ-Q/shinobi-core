// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.ShinobiCoreConfig;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

/**
 * Handles input detection: key presses, edges, double shift.
 * Does NOT apply physics - only detects intent.
 */
public final class MovementInputService {

    private MovementInputService() {}

    private static boolean jumpPressedThisTick = false;
    private static boolean jumpWasDown = false;
    private static boolean sneakPressedThisTick = false;
    private static boolean sneakWasDown = false;

    /**
     * Called every client tick. Detects input edges.
     */
    public static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        // Jump edge detection
        boolean jumpDown = client.options.jumpKey.isPressed();
        jumpPressedThisTick = jumpDown && !jumpWasDown;
        jumpWasDown = jumpDown;

        // Sneak (Shift) edge detection + double tap
        boolean sneakDown = client.options.sneakKey.isPressed();
        sneakPressedThisTick = sneakDown && !sneakWasDown;

        if (sneakPressedThisTick) {
            handleShiftPress(player);
        }
        sneakWasDown = sneakDown;
    }

    private static void handleShiftPress(ClientPlayerEntity player) {
        long now = System.currentTimeMillis();
        long lastPress = ClientMovementState.getLastShiftPressTime();
        int doubleTapMs = ShinobiCoreConfig.getInstance().movement.doubleTapShiftMs;

        if (now - lastPress < doubleTapMs) {
            // Double Shift detected
            ClientMovementState.setLastShiftPressTime(0); // Reset to prevent triple
            onDoubleShift(player);
        } else {
            ClientMovementState.setLastShiftPressTime(now);
            onSingleShift(player);
        }
    }

    /**
     * Single Shift: if sprinting forward -> slide, otherwise normal sneak.
     */
    private static void onSingleShift(ClientPlayerEntity player) {
        if (player.isOnGround() && player.isSprinting()
                && player.input.movementForward > 0) {
            ClientMovementService.tryStartSlide(player);
        }
        // Normal sneak is handled by vanilla
    }

    /**
     * Double Shift: toggle crawl.
     * If crawling -> stand up (if no block above).
     * If not crawling -> crawl.
     */
    private static void onDoubleShift(ClientPlayerEntity player) {
        ClientMovementService.toggleCrawl(player);
    }

    // === Getters ===
    public static boolean wasJumpPressed() { return jumpPressedThisTick; }
    public static boolean isJumpHeld() { return jumpWasDown; }
    public static boolean wasSneakPressed() { return sneakPressedThisTick; }
    public static boolean isSneakHeld() { return sneakWasDown; }



    /**
     * Check if player can perform movement actions.
     */
    public static boolean canPerformActions(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return false;
        if (player.isDead()) return false;
        if (player.hasVehicle()) return false;
        if (player.getAbilities().flying) return false;
        if (client.currentScreen != null) return false;
        return true;
    }
}