// SHINOBICORE:SPRINT7:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 7 slide foundation.
 *
 * Entry:
 * - player is on ground
 * - player is sprinting
 * - player is moving forward
 * - sneak key pressed once
 *
 * Behavior:
 * - forward impulse
 * - velocity friction
 * - ends after duration or jump
 */
public final class SlideClient {
    public static final int SLIDE_DURATION_TICKS = 14;
    public static final int SLIDE_COOLDOWN_TICKS = 20;

    public static final double SLIDE_BOOST = 0.42;
    public static final double SLIDE_FRICTION = 0.92;
    public static final double MIN_SLIDE_SPEED = 0.08;

    private static boolean active = false;
    private static int ticks = 0;
    private static int cooldown = 0;

    private SlideClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.slide) {
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

            if (ticks > SLIDE_DURATION_TICKS) {
                stop(player);
                return;
            }

            if (MovementInputService.wasJumpPressed()) {
                stop(player);
                return;
            }

            Vec3d velocity = player.getVelocity();
            double speed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);

            if (speed < MIN_SLIDE_SPEED) {
                stop(player);
                return;
            }

            player.setVelocity(
                    velocity.x * SLIDE_FRICTION,
                    velocity.y,
                    velocity.z * SLIDE_FRICTION
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

        if (!player.isSprinting()) {
            return;
        }

        if (!MovementInputService.isMovingForward(player)) {
            return;
        }

        if (MovementInputService.wasSneakPressed()) {
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
        cooldown = SLIDE_COOLDOWN_TICKS;

        ClientMovementState.setPhase(MovementPhase.SLIDING);
        ClientMovementState.setSliding(true);

        Vec3d velocity = player.getVelocity();

        player.setVelocity(
                look.x * SLIDE_BOOST,
                velocity.y,
                look.z * SLIDE_BOOST
        );

        player.velocityModified = true;
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ticks = 0;

        ClientMovementState.setSliding(false);

        if (ClientMovementState.getPhase() == MovementPhase.SLIDING) {
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