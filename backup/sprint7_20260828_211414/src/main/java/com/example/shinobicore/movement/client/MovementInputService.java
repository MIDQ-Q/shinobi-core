// SHINOBICORE:SPRINT6:FILE
package com.example.shinobicore.movement.client;

import net.minecraft.client.network.ClientPlayerEntity;

/**
 * SPRINT 6 safe input service.
 */
public final class MovementInputService {
    private static boolean wasJumping = false;
    private static boolean jumpPressedEdge = false;

    private MovementInputService() {}

    public static void update(ClientPlayerEntity player) {
        boolean jumping = player != null
                && player.input != null
                && player.input.jumping;

        jumpPressedEdge = jumping && !wasJumping;
        wasJumping = jumping;
    }

    public static boolean wasJumpPressed() {
        return jumpPressedEdge;
    }

    public static boolean isJumpHeld(ClientPlayerEntity player) {
        return player != null
                && player.input != null
                && player.input.jumping;
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