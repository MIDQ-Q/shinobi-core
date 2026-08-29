// SHINOBICORE:SPRINT8:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 8 dodge foundation.
 *
 * Keys:
 * - Z: dodge left
 * - C: dodge right
 *
 * Behavior:
 * - sideways impulse relative to look direction
 * - small forward assist if W is held
 * - short duration
 * - i-frames flag
 * - cooldown
 */
public final class DodgeClient {
    public static final int DODGE_DURATION_TICKS = 8;
    public static final int DODGE_COOLDOWN_TICKS = 20;
    public static final int IFRAME_TICKS = 8;

    public static final double DODGE_BOOST = 0.48;
    public static final double DODGE_FRICTION = 0.90;
    public static final double MIN_DODGE_SPEED = 0.06;
    public static final double FORWARD_ASSIST = 0.35;

    private static boolean active = false;
    private static int ticks = 0;
    private static int cooldown = 0;

    private DodgeClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) {
            cooldown--;
        }

        if (!FeatureFlags.dodge) {
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

            if (ticks > DODGE_DURATION_TICKS) {
                stop(player);
                return;
            }

            Vec3d velocity = player.getVelocity();
            double speed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);

            if (speed < MIN_DODGE_SPEED) {
                stop(player);
                return;
            }

            player.setVelocity(
                    velocity.x * DODGE_FRICTION,
                    velocity.y,
                    velocity.z * DODGE_FRICTION
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

        if (RollDodgeInputHandler.wasDodgeLeftPressed()) {
            start(player, -1);
        } else if (RollDodgeInputHandler.wasDodgeRightPressed()) {
            start(player, 1);
        }
    }

    private static void start(ClientPlayerEntity player, int side) {
        Vec3d look = getHorizontalLook(player);

        if (look == null) {
            return;
        }

        Vec3d up = new Vec3d(0.0, 1.0, 0.0);

        // Right vector relative to look direction.
        Vec3d right = look.crossProduct(up);

        Vec3d direction = right.multiply(side);

        float forward = MovementInputService.getForwardInput(player);

        if (forward > 0.1f) {
            direction = direction.add(look.multiply(FORWARD_ASSIST));
        }

        if (direction.lengthSquared() < 1.0E-6) {
            return;
        }

        direction = direction.normalize();

        active = true;
        ticks = 0;
        cooldown = DODGE_COOLDOWN_TICKS;

        ClientMovementState.setPhase(MovementPhase.DODGING);
        ClientMovementState.setIframeTicks(IFRAME_TICKS);

        Vec3d velocity = player.getVelocity();

        player.setVelocity(
                direction.x * DODGE_BOOST,
                velocity.y,
                direction.z * DODGE_BOOST
        );

        player.velocityModified = true;
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;
        ticks = 0;

        if (ClientMovementState.getPhase() == MovementPhase.DODGING) {
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