// SHINOBICORE:SPRINT5:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 5 wall running foundation.
 *
 * Rules:
 * - Requires Chakra Mode.
 * - Requires forward movement.
 * - Requires airborne state.
 * - Detects wall with short horizontal raycast.
 * - Softly reduces falling speed.
 * - Softly sticks player toward wall.
 *
 * No camera roll and no model animation yet.
 */
public final class WallRunClient {
    public static final int MAX_WALL_TICKS = 30;
    public static final double MAX_START_FALL_SPEED = 0.2;
    public static final double MIN_FALL_SPEED = -0.08;
    public static final double WALL_STICK_STRENGTH = 0.04;

    private static boolean active = false;
    private static Vec3d wallNormal = null;
    private static int ticksOnWall = 0;

    private WallRunClient() {}

    public static boolean isActive() {
        return active;
    }

    public static Vec3d getWallNormal() {
        return wallNormal;
    }

    public static int getTicksOnWall() {
        return ticksOnWall;
    }

    public static void tick(ClientPlayerEntity player) {
        if (player == null || player.getWorld() == null) {
            return;
        }

        if (!FeatureFlags.wallRun) {
            stop(player);
            return;
        }

        if (WaterWalkClient.isActive()) {
            stop(player);
            return;
        }

        if (!ChakraClientController.isChakraModeActive()) {
            stop(player);
            return;
        }

        if (player.isOnGround()) {
            stop(player);
            return;
        }

        if (player.isTouchingWater()) {
            stop(player);
            return;
        }

        if (MovementInputService.isSneaking(player)) {
            stop(player);
            return;
        }

        if (!MovementInputService.isMovingForward(player)) {
            stop(player);
            return;
        }

        if (player.getVelocity().y > MAX_START_FALL_SPEED) {
            stop(player);
            return;
        }

        Vec3d normal = WallDetector.detectWallNormal(player);

        if (normal == null) {
            stop(player);
            return;
        }

        if (!active) {
            active = true;
            wallNormal = normal;
            ticksOnWall = 0;
            ClientMovementState.setPhase(MovementPhase.WALL_RUNNING);
            ClientMovementState.setOnWall(true);
        }

        ticksOnWall++;

        MovementChakraConfig config = MovementChakraConfig.getInstance();
        float drain = 0.075f;

        if (config != null && config.chakra != null) {
            drain = config.chakra.wallWalkDrainPerTick;
        }

        if (!ChakraClientController.consumeChakra(drain)) {
            stop(player);
            return;
        }

        Vec3d velocity = player.getVelocity();

        double newY = Math.max(velocity.y, MIN_FALL_SPEED);
        double stickX = -normal.x * WALL_STICK_STRENGTH;
        double stickZ = -normal.z * WALL_STICK_STRENGTH;

        player.setVelocity(
                velocity.x + stickX,
                newY,
                velocity.z + stickZ
        );

        player.velocityModified = true;
        player.fallDistance = 0.0f;

        if (ticksOnWall > MAX_WALL_TICKS) {
            stop(player);
        }
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        wallNormal = null;
        ticksOnWall = 0;

        ClientMovementState.setOnWall(false);

        if (ClientMovementState.getPhase() == MovementPhase.WALL_RUNNING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}