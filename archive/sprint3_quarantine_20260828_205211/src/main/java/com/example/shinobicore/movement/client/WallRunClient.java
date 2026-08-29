// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.WallDetector;
import com.example.shinobicore.util.ShinobiLogger;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

/**
 * Client-side wall running logic.
 *
 * ENTRY RULES (from plan):
 * - Chakra mode active
 * - Chakra > 0
 * - Not exhausted
 * - NOT on ground
 * - NOT in water
 * - Recently jumped (within jumpGraceTicks)
 * - Moving toward wall
 * - Wall found + block allowed
 * - No corner conflict
 * - Cooldown expired
 *
 * NO AUTO-STICK. Entry ONLY via jump + move toward wall.
 */
public final class WallRunClient {

    private WallRunClient() {}

    private static int ticksOnWall = 0;
    private static int wallLostTicks = 0;
    private static final int MAX_WALL_LOST_TICKS = 4; // Exit if wall lost for 4+ ticks

    /**
     * Try to start wall running.
     * Called from ClientMovementService during NORMAL phase.
     */
    public static boolean tryStart(ClientPlayerEntity player) {
        ShinobiCoreConfig.WallRunSection cfg = ShinobiCoreConfig.getInstance().wallRun;
        if (!cfg.enabled) return false;

        // Must have chakra mode active
        if (!ClientChakraController.isChakraModeActive()) return false;

        // Must have chakra
        if (ClientChakraController.getCurrentChakra() <= 0) return false;

        // Must not be exhausted
        if (ClientChakraController.isExhausted()) return false;

        // Must NOT be on ground
        if (player.isOnGround()) return false;

        // Must NOT be in water
        if (player.isTouchingWater()) return false;

        // Must have recently jumped (grace period)
        if (cfg.entryRequiresJump && ClientMovementState.getJumpGraceTicks() <= 0) return false;

        // Cooldown check
        if (ClientMovementState.getWallCooldown() > 0) return false;

        // Find wall
        Vec3d wallNormal = WallDetector.getWallNormal(player);
        if (wallNormal == null) return false;

        // Must be moving toward wall
        if (!WallDetector.isMovingTowardWall(player, wallNormal)) return false;

        // No corner conflict
        if (WallDetector.isCornerConflict(player)) return false;

        // Get wall block pos for packet
        BlockPos wallPos = WallDetector.getWallBlockPos(player);

        // === START WALL RUN ===
        ClientMovementState.setPhase(MovementPhase.WALL_RUNNING);
        ClientMovementState.setWallNormal(wallNormal);
        ClientMovementState.setWallBlockPos(wallPos);
        ticksOnWall = 0;
        wallLostTicks = 0;

        // Consume fatigue on start
        ClientChakraController.addFatigue(cfg.fatigueCostOnStart);

        // Send packet to server
        ClientMovementService.sendAction(player, MovementActionType.WALL_START, wallNormal);

        return true;
    }

    /**
     * Tick wall running logic.
     * Called from ClientMovementService when in WALL_RUNNING phase.
     */
    public static void tick(ClientPlayerEntity player) {
        ShinobiCoreConfig.WallRunSection cfg = ShinobiCoreConfig.getInstance().wallRun;

        ticksOnWall++;

        // === CHECK EXIT CONDITIONS ===
        if (shouldExit(player, cfg)) {
            stop(player);
            return;
        }

        // === UPDATE WALL NORMAL (every 2 ticks) ===
        if (ticksOnWall % 2 == 0) {
            Vec3d newNormal = WallDetector.getWallNormal(player);
            if (newNormal != null) {
                ClientMovementState.setWallNormal(newNormal);
                wallLostTicks = 0;
            } else {
                wallLostTicks++;
                if (wallLostTicks >= MAX_WALL_LOST_TICKS) {
                    stop(player);
                    return;
                }
            }
        }

        // === DRAIN CHAKRA ===
        float drainPerTick = cfg.drainPerSecond / 20.0f;
        if (!ClientChakraController.spendChakra(drainPerTick)) {
            // No chakra left - exit
            stop(player);
            return;
        }

        // === ADD FATIGUE ===
        ClientChakraController.addFatigue(cfg.fatiguePerSecond / 20.0f);

        // === MAX DURATION ===
        if (ticksOnWall >= cfg.maxDurationTicks) {
            stop(player);
            return;
        }

        // === WALL JUMP ===
        if (MovementInputService.wasJumpPressed()) {
            performWallJump(player, cfg);
            return;
        }

        // === SNEAK EXIT ===
        if (player.isSneaking()) {
            stop(player);
            return;
        }

        // === MOVEMENT ON WALL ===
        applyWallMovement(player, cfg);
    }

    /**
     * Apply movement while on wall.
     * Input is projected onto wall plane.
     */
    private static void applyWallMovement(ClientPlayerEntity player, ShinobiCoreConfig.WallRunSection cfg) {
        Vec3d wallNormal = ClientMovementState.getWallNormal();
        if (wallNormal == null) return;

        // Get input
        float inputForward = player.input.movementForward;
        float inputStrafe = player.input.movementSideways;

        // Get look direction projected onto wall plane
        Vec3d look = player.getRotationVector();
        Vec3d lookOnWall = look.subtract(wallNormal.multiply(look.dotProduct(wallNormal)));
        if (lookOnWall.lengthSquared() < 0.001) {
            lookOnWall = new Vec3d(0, 1, 0); // Fallback: up
        }
        lookOnWall = lookOnWall.normalize();

        // Right vector along wall
        Vec3d rightOnWall = lookOnWall.crossProduct(wallNormal).normalize();

        // Calculate desired velocity on wall plane
        Vec3d desiredVel = lookOnWall.multiply(inputForward * cfg.speedMultiplier)
            .add(rightOnWall.multiply(inputStrafe * cfg.speedMultiplier));

        // Apply gravity (reduced)
        double gravityY = -0.08 * cfg.gravityScale;

        // If no input: slow slide down
        if (Math.abs(inputForward) < 0.01 && Math.abs(inputStrafe) < 0.01) {
            desiredVel = new Vec3d(desiredVel.x, -cfg.idleSlidePerTick, desiredVel.z);
        }

        // Clamp vertical speed
        double velY = desiredVel.y + gravityY;
        velY = Math.max(-cfg.maxDescendSpeed, Math.min(cfg.maxClimbSpeed, velY));

        // Final velocity
        Vec3d finalVel = new Vec3d(desiredVel.x, velY, desiredVel.z);

        // Soft stick to wall (prevent drifting away)
        Vec3d pos = player.getPos();
        Vec3d checkPos = pos.subtract(wallNormal.multiply(cfg.raycastDistance * 0.5));
        // If player is slightly away from wall, gently pull back
        // (handled in mixin via velocity adjustment)

        player.setVelocity(finalVel.x, finalVel.y, finalVel.z);
        player.fallDistance = 0f;
    }

    /**
     * Perform wall jump.
     * Soft jump in look direction with wall-push protection.
     */
    private static void performWallJump(ClientPlayerEntity player, ShinobiCoreConfig.WallRunSection cfg) {
        Vec3d wallNormal = ClientMovementState.getWallNormal();
        if (wallNormal == null) wallNormal = new Vec3d(0, 0, 1);

        // Get look direction
        Vec3d look = player.getRotationVector();

        // Calculate jump velocity
        Vec3d jumpVel = look.multiply(cfg.wallJumpLookFactor)
            .add(0, cfg.wallJumpVertical, 0);

        // PROTECTION: if looking INTO wall, reduce wall-component
        double intoWall = jumpVel.x * (-wallNormal.x) + jumpVel.z * (-wallNormal.z);
        if (intoWall > 0 && cfg.preventJumpIntoWall) {
            // Remove/reduce component going into wall
            jumpVel = jumpVel.add(wallNormal.multiply(intoWall * 0.8));
        }

        // Add horizontal push away from wall
        jumpVel = jumpVel.add(wallNormal.multiply(cfg.wallJumpHorizontal));

        // Apply
        player.setVelocity(jumpVel.x, jumpVel.y, jumpVel.z);
        player.velocityModified = true;
        player.fallDistance = 0f;

        // Exit wall run
        ClientMovementState.setPhase(MovementPhase.NORMAL);
        ClientMovementState.setWallNormal(null);
        ClientMovementState.setWallBlockPos(null);
        ClientMovementState.setWallCooldown(cfg.cooldownTicks);
        ticksOnWall = 0;

        // Send packet
        ClientMovementService.sendAction(player, MovementActionType.WALL_JUMP);
    }

    /**
     * Stop wall running (normal exit).
     */
    public static void stop(ClientPlayerEntity player) {
        if (ClientMovementState.getPhase() != MovementPhase.WALL_RUNNING) return;

        ShinobiCoreConfig.WallRunSection cfg = ShinobiCoreConfig.getInstance().wallRun;

        ClientMovementState.setPhase(MovementPhase.NORMAL);
        ClientMovementState.setWallNormal(null);
        ClientMovementState.setWallBlockPos(null);
        ClientMovementState.setWallCooldown(cfg.cooldownTicks);
        ticksOnWall = 0;
        wallLostTicks = 0;

        // Send packet
        ClientMovementService.sendAction(player, MovementActionType.WALL_STOP);
    }

    /**
     * Check if wall run should exit.
     */
    private static boolean shouldExit(ClientPlayerEntity player, ShinobiCoreConfig.WallRunSection cfg) {
        // Landed on ground
        if (player.isOnGround()) return true;

        // Entered water
        if (player.isTouchingWater()) return true;

        // Chakra mode turned off
        if (!ClientChakraController.isChakraModeActive()) return true;

        // Exhausted
        if (ClientChakraController.isExhausted()) return true;

        return false;
    }

    public static int getTicksOnWall() {
        return ticksOnWall;
    }
}