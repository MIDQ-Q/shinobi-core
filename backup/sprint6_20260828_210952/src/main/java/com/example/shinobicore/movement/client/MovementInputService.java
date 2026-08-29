// SHINOBICORE:SPRINT5:FILE
package com.example.shinobicore.movement.client;

import net.minecraft.client.network.ClientPlayerEntity;

/**
 * SPRINT 5 safe input service.
 */
public final class MovementInputService {
    private MovementInputService() {}

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
}