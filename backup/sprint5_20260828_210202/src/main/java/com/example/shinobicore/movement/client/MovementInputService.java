// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.movement.client;

import net.minecraft.client.network.ClientPlayerEntity;

/**
 * SPRINT 4 safe input service.
 */
public final class MovementInputService {
    private MovementInputService() {}

    public static boolean isSneaking(ClientPlayerEntity player) {
        return player != null && player.isSneaking();
    }

    public static boolean isSprinting(ClientPlayerEntity player) {
        return player != null && player.isSprinting();
    }
}