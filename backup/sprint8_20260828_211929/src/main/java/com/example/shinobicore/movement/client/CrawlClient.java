// SHINOBICORE:SPRINT7:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 7 crawl foundation.
 *
 * Entry/Exit:
 * - double tap Shift on ground
 *
 * Behavior:
 * - forces sneaking pose
 * - disables sprint
 * - limits horizontal speed
 * - suppresses upward jump velocity
 */
public final class CrawlClient {
    public static final double MAX_CRAWL_SPEED = 0.06;

    private static boolean active = false;

    private CrawlClient() {}

    public static boolean isActive() {
        return active;
    }

    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.crawl) {
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

        if (SlideClient.isActive()) {
            stop(player);
            return;
        }

        if (player.isTouchingWater()) {
            stop(player);
            return;
        }

        if (MovementInputService.wasDoubleSneakPressed() && player.isOnGround()) {
            toggle(player);
            return;
        }

        if (!active) {
            return;
        }

        if (!player.isOnGround()) {
            stop(player);
            return;
        }

        if (!player.isSneaking()) {
            player.setSneaking(true);
        }

        player.setSprinting(false);

        Vec3d velocity = player.getVelocity();
        double speed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);

        if (speed > MAX_CRAWL_SPEED) {
            double scale = MAX_CRAWL_SPEED / speed;
            velocity = new Vec3d(
                    velocity.x * scale,
                    velocity.y,
                    velocity.z * scale
            );
        }

        if (velocity.y > 0.0) {
            velocity = new Vec3d(velocity.x, 0.0, velocity.z);
        }

        player.setVelocity(velocity.x, velocity.y, velocity.z);
        player.velocityModified = true;

        ClientMovementState.setPhase(MovementPhase.CRAWLING);
    }

    private static void toggle(ClientPlayerEntity player) {
        if (active) {
            stop(player);
        } else {
            start(player);
        }
    }

    private static void start(ClientPlayerEntity player) {
        active = true;

        ClientMovementState.setCrawling(true);
        ClientMovementState.setPhase(MovementPhase.CRAWLING);

        player.setSprinting(false);
        player.setSneaking(true);
    }

    private static void stop(ClientPlayerEntity player) {
        if (!active) {
            return;
        }

        active = false;

        ClientMovementState.setCrawling(false);

        if (ClientMovementState.getPhase() == MovementPhase.CRAWLING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }

        if (!MovementInputService.isSneakHeld(player)) {
            player.setSneaking(false);
        }
    }
}