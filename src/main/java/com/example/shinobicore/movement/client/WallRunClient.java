// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 8 wall running with wall jump.
 */
public final class WallRunClient {
    public static final int MAX_WALL_TICKS = 45;
    public static final int MAX_WALL_LOST_TICKS = 4;

    public static final double CLIMB_SPEED = 0.07;
    public static final double DESCEND_SPEED = -0.05;
    public static final double IDLE_SLIDE = -0.02;
    public static final double STICK_STRENGTH = 0.06;

    public static final double WALL_JUMP_HORIZONTAL = 0.35;
    public static final double WALL_JUMP_VERTICAL = 0.42;
    public static final double WALL_JUMP_LOOK_FACTOR = 0.25;

    private static boolean active = false;
    private static int ticksOnWall = 0;
    private static int wallLostTicks = 0;

    private WallRunClient() {}

    public static boolean isActive() { return active; }
    public static int getTicksOnWall() { return ticksOnWall; }

    public static void tick(ClientPlayerEntity player) {
        if (player == null || player.getWorld() == null) return;
        if (!FeatureFlags.wallRun) { stop(player); return; }
        if (WaterWalkClient.isActive()) { stop(player); return; }
        if (!ChakraClientController.isChakraModeActive()) { stop(player); return; }
        if (player.isOnGround()) { stop(player); return; }
        if (player.isTouchingWater()) { stop(player); return; }
        if (MovementInputService.isSneaking(player)) { stop(player); return; }

        if (!active && ClientMovementState.getWallCooldownTicks() > 0) return;

        Vec3d normal = WallDetector.detectWallNormal(player);

        if (normal == null) {
            if (active) {
                wallLostTicks++;
                if (wallLostTicks >= MAX_WALL_LOST_TICKS) stop(player);
            }
            return;
        }

        wallLostTicks = 0;

        if (!active) {
            if (!MovementInputService.hasHorizontalInput(player)) return;
            if (!MovementInputService.isMovingForward(player) && !player.horizontalCollision) return;
            if (!WallDetector.isMovingTowardWall(player, normal) && !player.horizontalCollision) return;
            if (player.getVelocity().y > 0.25) return;
            if (ClientMovementState.getJumpGraceTicks() <= 0 && !player.horizontalCollision) return;

            active = true;
            ticksOnWall = 0;
            ClientMovementState.setPhase(MovementPhase.WALL_RUNNING);
            ClientMovementState.setOnWall(true);
        }

        ClientMovementState.setWallNormal(normal);
        ticksOnWall++;

        MovementChakraConfig config = MovementChakraConfig.getInstance();
        float drain = 0.075f;
        if (config != null && config.chakra != null) drain = config.chakra.wallWalkDrainPerTick;

        if (!ChakraClientController.consumeChakra(drain)) { stop(player); return; }

        if (MovementInputService.wasJumpPressed()) {
            performWallJump(player, normal);
            return;
        }

        applyWallPhysics(player, normal);
        if (ticksOnWall > MAX_WALL_TICKS) stop(player);
    }

    private static void applyWallPhysics(ClientPlayerEntity player, Vec3d normal) {
        Vec3d velocity = player.getVelocity();
        double intoWall = velocity.x * normal.x + velocity.z * normal.z;
        if (intoWall < 0.0) velocity = velocity.subtract(normal.multiply(intoWall));

        float forward = MovementInputService.getForwardInput(player);
        double vertical;
        if (forward > 0.1f) vertical = CLIMB_SPEED;
        else if (forward < -0.1f) vertical = DESCEND_SPEED;
        else vertical = IDLE_SLIDE;

        double stickX = -normal.x * STICK_STRENGTH;
        double stickZ = -normal.z * STICK_STRENGTH;
        player.setVelocity(velocity.x + stickX, vertical, velocity.z + stickZ);
        player.velocityModified = true;
        player.fallDistance = 0.0f;
    }

    private static void performWallJump(ClientPlayerEntity player, Vec3d normal) {
        Vec3d look = player.getRotationVector();
        Vec3d jumpVelocity = new Vec3d(
                look.x * WALL_JUMP_LOOK_FACTOR,
                WALL_JUMP_VERTICAL,
                look.z * WALL_JUMP_LOOK_FACTOR
        );
        jumpVelocity = jumpVelocity.add(normal.multiply(WALL_JUMP_HORIZONTAL));
        double intoWall = jumpVelocity.x * normal.x + jumpVelocity.z * normal.z;
        if (intoWall < 0.0) jumpVelocity = jumpVelocity.subtract(normal.multiply(intoWall));

        player.setVelocity(jumpVelocity.x, jumpVelocity.y, jumpVelocity.z);
        player.velocityModified = true;
        player.fallDistance = 0.0f;
        stop(player);
        ClientMovementState.setWallCooldownTicks(8);
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) return;
        active = false;
        ticksOnWall = 0;
        wallLostTicks = 0;
        ClientMovementState.setOnWall(false);
        ClientMovementState.setWallNormal(null);
        if (ClientMovementState.getPhase() == MovementPhase.WALL_RUNNING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}