// SHINOBICORE:SPRINT11:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.client.input.KeyBindings;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 11 meditation foundation.
 *
 * Entry:
 * - player is on ground
 * - player is in chakra mode
 * - player presses M key
 *
 * Behavior:
 * - accelerated chakra regen
 * - player cannot move
 * - interrupted by movement, jump, or M key press
 */
public final class MeditationClient {
    private static boolean active = false;
    private static boolean wasMeditatePressed = false;

    private MeditationClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        boolean meditatePressed = isMeditateKeyDown();
        boolean edge = meditatePressed && !wasMeditatePressed;
        wasMeditatePressed = meditatePressed;

        if (!FeatureFlags.meditation) {
            stop(player);
            return;
        }

        if (WaterWalkClient.isActive()) {
            stop(player);
            return;
        }

        if (WallRunClient.isActive()) {
            stop(player);
            return;
        }

        if (RollClient.isActive()) {
            stop(player);
            return;
        }

        if (DodgeClient.isActive()) {
            stop(player);
            return;
        }

        if (SlideClient.isActive()) {
            stop(player);
            return;
        }

        if (CrawlClient.isActive()) {
            stop(player);
            return;
        }

        if (player.isTouchingWater()) {
            stop(player);
            return;
        }

        if (active) {
            // Interrupt on movement
            if (MovementInputService.hasHorizontalInput(player)) {
                stop(player);
                return;
            }

            // Interrupt on jump
            if (MovementInputService.wasJumpPressed()) {
                stop(player);
                return;
            }

            // Interrupt on M key press
            if (edge) {
                stop(player);
                return;
            }

            // Interrupt if not on ground
            if (!player.isOnGround()) {
                stop(player);
                return;
            }

            // Accelerated chakra regen
            ChakraClientController.setMeditating(true);
            return;
        }

        if (!player.isOnGround()) {
            return;
        }

        if (!ChakraClientController.isChakraModeActive()) {
            return;
        }

        if (edge) {
            start(player);
        }
    }

    private static void start(ClientPlayerEntity player) {
        active = true;
        ClientMovementState.setPhase(MovementPhase.MEDITATING);
        ClientMovementState.setMeditating(true);
        ChakraClientController.setMeditating(true);
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ClientMovementState.setMeditating(false);
        ChakraClientController.setMeditating(false);

        if (ClientMovementState.getPhase() == MovementPhase.MEDITATING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }

    private static boolean isMeditateKeyDown() {
        KeyBinding key = KeyBindings.MEDITATE;
        return key != null && key.isPressed();
    }
}