// SHINOBICORE:SPRINT7:FILE
package com.example.shinobicore.movement.client;

import net.minecraft.client.network.ClientPlayerEntity;

/**
 * SPRINT 7 safe input service.
 * Tracks jump, sneak, and double sneak edges.
 */
public final class MovementInputService {
    private static boolean wasJumping = false;
    private static boolean jumpPressedEdge = false;

    private static boolean wasSneaking = false;
    private static boolean sneakPressedEdge = false;
    private static int ticksSinceSneakPress = 1000;
    private static boolean doubleSneakPressedEdge = false;

    private MovementInputService() {}

    public static void update(ClientPlayerEntity player) {
        boolean jumping = player != null
                && player.input != null
                && player.input.jumping;

        jumpPressedEdge = jumping && !wasJumping;
        wasJumping = jumping;

        boolean sneaking = player != null
                && player.input != null
                && player.input.sneaking;

        sneakPressedEdge = sneaking && !wasSneaking;
        wasSneaking = sneaking;

        ticksSinceSneakPress++;
        doubleSneakPressedEdge = false;

        if (sneakPressedEdge) {
            if (ticksSinceSneakPress <= 8) {
                doubleSneakPressedEdge = true;
            }

            ticksSinceSneakPress = 0;
        }
    }

    public static boolean wasJumpPressed() {
        return jumpPressedEdge;
    }

    public static boolean wasSneakPressed() {
        return sneakPressedEdge;
    }

    public static boolean wasDoubleSneakPressed() {
        return doubleSneakPressedEdge;
    }

    public static boolean isJumpHeld(ClientPlayerEntity player) {
        return player != null
                && player.input != null
                && player.input.jumping;
    }

    public static boolean isSneakHeld(ClientPlayerEntity player) {
        return player != null
                && player.input != null
                && player.input.sneaking;
    }

    public static boolean isSneaking(ClientPlayerEntity player) {
        return player != null && player.isSneaking();
    }

    public static boolean isSprinting(ClientPlayerEntity player) {
        return player != null && player.isSprinting();
    }

    public static boolean isMovingForward(ClientPlayerEntity player) {
        return player != null
                && player.input != null
                && player.input.movementForward > 0.1f;
    }

    public static boolean hasHorizontalInput(ClientPlayerEntity player) {
        if (player == null || player.input == null) {
            return false;
        }

        return Math.abs(player.input.movementForward) > 0.1f
                || Math.abs(player.input.movementSideways) > 0.1f;
    }

    public static float getForwardInput(ClientPlayerEntity player) {
        if (player == null || player.input == null) {
            return 0.0f;
        }

        return player.input.movementForward;
    }
}