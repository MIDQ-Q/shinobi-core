// SHINOBICORE:SPRINT10:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

/**
 * SPRINT 10 edge grab foundation.
 *
 * Entry:
 * - player is in air and falling
 * - there is a block edge below at body level
 * - there is headroom above the edge
 *
 * Behavior:
 * - grab edge and stop falling
 * - hold W or press Space to climb up
 * - press S or Shift to release
 * - cooldown after grab
 */
public final class EdgeGrabClient {
    public static final int COOLDOWN_TICKS = 20;
    public static final int MAX_HANG_TICKS = 40;
    public static final double CLIMB_UP_Y = 1.5;

    private static boolean active = false;
    private static int ticksOnEdge = 0;
    private static int cooldown = 0;

    private EdgeGrabClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.edgeGrab) {
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

        if (player.isTouchingWater()) {
            stop(player);
            return;
        }

        if (active) {
            ticksOnEdge++;

            // Cancel falling
            Vec3d velocity = player.getVelocity();
            if (velocity.y < 0) {
                player.setVelocity(velocity.x, 0, velocity.z);
                player.velocityModified = true;
            }

            player.fallDistance = 0;

            // Climb up: hold W or press Space
            if (MovementInputService.isMovingForward(player) || MovementInputService.wasJumpPressed()) {
                climbUp(player);
                return;
            }

            // Release: press S or sneak
            if (MovementInputService.isSneaking(player) || MovementInputService.getForwardInput(player) < -0.1f) {
                stop(player);
                return;
            }

            // Timeout: too long hanging
            if (ticksOnEdge > MAX_HANG_TICKS) {
                stop(player);
                return;
            }

            return;
        }

        if (cooldown > 0) {
            return;
        }

        if (player.isOnGround()) {
            return;
        }

        if (player.getVelocity().y > -0.1) {
            return;
        }

        if (tryGrab(player)) {
            start(player);
        }
    }

    private static boolean tryGrab(ClientPlayerEntity player) {
        Vec3d look = getHorizontalLook(player);

        if (look == null) {
            return false;
        }

        Vec3d feetPos = player.getPos();
        Vec3d checkPos = feetPos.add(look.x * 0.5, -0.5, look.z * 0.5);

        BlockPos blockPos = new BlockPos((int) Math.floor(checkPos.x), (int) Math.floor(checkPos.y), (int) Math.floor(checkPos.z));
        World world = player.getWorld();

        // Block at body level (the edge)
        boolean hasEdge = !world.isAir(blockPos);

        // Headroom above the edge (where player will climb)
        BlockPos headPos = blockPos.up(2);
        boolean hasHeadroom = world.isAir(headPos) || world.isAir(headPos.up(1));

        return hasEdge && hasHeadroom;
    }

    private static void start(ClientPlayerEntity player) {
        active = true;
        ticksOnEdge = 0;
        cooldown = COOLDOWN_TICKS;

        ClientMovementState.setPhase(MovementPhase.EDGE_GRABBING);

        // Stop all movement
        player.setVelocity(0, 0, 0);
        player.velocityModified = true;
        player.fallDistance = 0;
    }

    private static void climbUp(ClientPlayerEntity player) {
        Vec3d position = player.getPos();
        player.addVelocity(0, 0.15, 0);
        player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);
        player.velocityModified = true;

        stop(player);
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ticksOnEdge = 0;

        if (ClientMovementState.getPhase() == MovementPhase.EDGE_GRABBING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }

    private static Vec3d getHorizontalLook(ClientPlayerEntity player) {
        Vec3d rotation = player.getRotationVector();
        Vec3d horizontal = new Vec3d(rotation.x, 0.0, rotation.z);

        if (horizontal.lengthSquared() < 1.0E-6) {
            return null;
        }

        return horizontal.normalize();
    }
}