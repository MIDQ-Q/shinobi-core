// SHINOBICORE:SPRINT9:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 9 charged jump foundation.
 *
 * Entry:
 * - player is on ground
 * - player holds jump key
 *
 * Behavior:
 * - charge while holding jump
 * - release to jump with power based on charge time
 * - vertical speed capped
 * - phase CHARGING_JUMP
 * - cooldown after release
 */
public final class ChargedJumpClient {
    public static final int MAX_CHARGE_TICKS = 20;
    public static final int COOLDOWN_TICKS = 20;

    public static final double MIN_JUMP_Y = 0.42;
    public static final double MAX_JUMP_Y = 1.0;
    public static final double JUMP_Y_CAP = 1.5;

    private static boolean charging = false;
    private static int chargeTicks = 0;
    private static int cooldown = 0;

    private ChargedJumpClient() {}

    public static boolean isCharging() {
        return charging;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.chargedJump) {
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

        if (CrawlClient.isActive()) {
            stop(player);
            return;
        }

        if (player.isTouchingWater()) {
            stop(player);
            return;
        }

        if (charging) {
            chargeTicks++;

            if (!player.isOnGround()) {
                release(player);
                return;
            }

            if (chargeTicks > MAX_CHARGE_TICKS) {
                release(player);
                return;
            }

            if (!MovementInputService.isJumpHeld(player)) {
                release(player);
                return;
            }

            // Slow player while charging
            Vec3d velocity = player.getVelocity();
            player.setVelocity(velocity.x * 0.8, velocity.y, velocity.z * 0.8);
            player.velocityModified = true;
            return;
        }

        if (cooldown > 0) {
            return;
        }

        if (!player.isOnGround()) {
            return;
        }

        if (SlideClient.isActive()) {
            return;
        }

        if (RollClient.isActive()) {
            return;
        }

        if (DodgeClient.isActive()) {
            return;
        }

        if (MovementInputService.isJumpHeld(player)) {
            start(player);
        }
    }

    private static void start(ClientPlayerEntity player) {
        charging = true;
        chargeTicks = 0;
        ClientMovementState.setPhase(MovementPhase.CHARGING_JUMP);
    }

    private static void release(ClientPlayerEntity player) {
        if (!charging) {
            return;
        }

        charging = false;
        cooldown = COOLDOWN_TICKS;

        float power = Math.min(chargeTicks / (float) MAX_CHARGE_TICKS, 1.0f);
        double jumpY = MIN_JUMP_Y + (MAX_JUMP_Y - MIN_JUMP_Y) * power;
        jumpY = Math.min(jumpY, JUMP_Y_CAP);

        if (player.isOnGround()) {
            player.jump();
            double bonus = jumpY - 0.42;
            if (bonus > 0) player.addVelocity(0, bonus, 0);
            player.velocityModified = true;
        } else {
            Vec3d velocity = player.getVelocity();
            player.setVelocity(velocity.x, jumpY, velocity.z);
            player.velocityModified = true;
        }

        if (ClientMovementState.getPhase() == MovementPhase.CHARGING_JUMP) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }

    private static void stop(ClientPlayerEntity player) {
        if (!charging) {
            return;
        }

        charging = false;
        chargeTicks = 0;

        if (ClientMovementState.getPhase() == MovementPhase.CHARGING_JUMP) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}