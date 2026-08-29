// SHINOBICORE:SPRINT9:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 9 double jump foundation.
 *
 * Entry:
 * - player is in air
 * - player presses jump key
 * - air jumps remaining
 *
 * Behavior:
 * - single air jump
 * - resets on ground contact
 */
public final class DoubleJumpClient {
    public static final double DOUBLE_JUMP_Y = 0.42;

    private DoubleJumpClient() {}

    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.doubleJump) {
            return;
        }

        // Reset air jumps on ground contact
        if (player.isOnGround()) {
            ClientMovementState.setAirJumpsUsed(0);
            return;
        }

        if (WaterWalkClient.isActive()) {
            return;
        }

        if (WallRunClient.isActive()) {
            return;
        }

        if (ChargedJumpClient.isCharging()) {
            return;
        }

        if (player.isTouchingWater()) {
            return;
        }

        if (MovementInputService.wasJumpPressed()) {
            int used = ClientMovementState.getAirJumpsUsed();
            int max = ClientMovementState.getMaxAirJumps();

            if (used < max) {
                Vec3d velocity = player.getVelocity();
                player.setVelocity(velocity.x, DOUBLE_JUMP_Y, velocity.z);
                player.velocityModified = true;
                ClientMovementState.setAirJumpsUsed(used + 1);
            }
        }
    }
}