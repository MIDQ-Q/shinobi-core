// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 8 roll foundation.
 *
 * Key: R
 * Behavior:
 * - forward impulse in look direction
 * - short duration
 * - i-frames flag
 * - cooldown
 */
public final class RollClient {
    public static final int ROLL_DURATION_TICKS = 12;
    public static final int ROLL_COOLDOWN_TICKS = 25;
    public static final int IFRAME_TICKS = 12;

    public static final double ROLL_BOOST = 0.55;
    public static final double ROLL_FRICTION = 0.93;
    public static final double MIN_ROLL_SPEED = 0.08;

    private static boolean active = false;
    private static int ticks = 0;
    private static int cooldown = 0;

    private RollClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.roll) {
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

        if (active) {
            ticks++;

            if (!player.isOnGround()) {
                stop(player);
                return;
            }

            if (ticks > ROLL_DURATION_TICKS) {
                stop(player);
                return;
            }

            Vec3d velocity = player.getVelocity();
            double speed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);

            if (speed < MIN_ROLL_SPEED) {
                stop(player);
                return;
            }

            player.setVelocity(
                    velocity.x * ROLL_FRICTION,
                    velocity.y,
                    velocity.z * ROLL_FRICTION
            );

            player.velocityModified = true;
            return;
        }

        if (cooldown > 0) {
            return;
        }

        if (!player.isOnGround()) {
            return;
        }

        if (MovementInputService.isSneaking(player)) {
            return;
        }

        if (RollDodgeInputHandler.wasRollPressed()) {
            start(player);
        }
    }

    private static void start(ClientPlayerEntity player) {
        Vec3d look = getHorizontalLook(player);

        if (look == null) {
            return;
        }

        active = true;
        ticks = 0;
        cooldown = ROLL_COOLDOWN_TICKS;

        ClientMovementState.setPhase(MovementPhase.ROLLING);
        ClientMovementState.setIframeTicks(IFRAME_TICKS);

        Vec3d velocity = player.getVelocity();

        player.setVelocity(
                look.x * ROLL_BOOST,
                velocity.y,
                look.z * ROLL_BOOST
        );

        player.velocityModified = true;
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ticks = 0;

        if (ClientMovementState.getPhase() == MovementPhase.ROLLING) {
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