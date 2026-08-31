// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.server;

import com.example.shinobicore.movement.common.WallDetector;
import com.example.shinobicore.util.ShinobiLogger;
import net.minecraft.block.BlockState;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

/**
 * Server-side wall validation.
 * ONLY LOGS suspicious activity. Does NOT punish or rollback.
 *
 * Checks:
 * - Is there actually a block in the claimed direction?
 * - Is the block allowed?
 * - Is the player close enough to the wall?
 */
public final class ServerWallValidator {

    private ServerWallValidator() {}

    /**
     * Validate WALL_START action from client.
     * Only logs if something is wrong.
     */
    public static void validateWallStart(ServerPlayerEntity player, Vec3d claimedNormal) {
        if (player == null || claimedNormal == null) return;

        // Check if there's a solid block in the claimed direction
        Vec3d eye = player.getEyePos();
        Vec3d checkPos = eye.subtract(claimedNormal.multiply(1.0));
        BlockPos blockPos = BlockPos.ofFloored(checkPos);

        BlockState state = player.getWorld().getBlockState(blockPos);

        if (state.isAir()) {
            logSuspicious(player, "WALL_START but no block at claimed position " + blockPos.toShortString());
            return;
        }

        // Check if block has collision
        if (state.getCollisionShape(player.getWorld(), blockPos).isEmpty()) {
            logSuspicious(player, "WALL_START but block has no collision at " + blockPos.toShortString());
            return;
        }

        // Check distance (player should be within ~1.5 blocks of wall)
        double dist = player.getPos().distanceTo(new Vec3d(
            blockPos.getX() + 0.5,
            blockPos.getY() + 0.5,
            blockPos.getZ() + 0.5
        ));

        if (dist > 2.5) {
            logSuspicious(player, "WALL_START but too far from wall: " + String.format("%.2f", dist));
        }
    }

    /**
     * Validate WALL_JUMP action.
     * Only logs.
     */
    public static void validateWallJump(ServerPlayerEntity player) {
        if (player == null) return;

        // Player should be in air when wall jumping
        if (player.isOnGround()) {
            logSuspicious(player, "WALL_JUMP but player is on ground");
        }
    }

    private static void logSuspicious(ServerPlayerEntity player, String message) {
        ShinobiLogger.warn("[WALL-SUS] %s: %s", player.getName().getString(), message);
    }
}