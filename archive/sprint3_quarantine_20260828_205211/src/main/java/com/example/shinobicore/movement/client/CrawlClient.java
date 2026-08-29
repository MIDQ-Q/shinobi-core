// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

/**
 * Crawl mechanic: double Shift on ground -> low pose, reduced speed.
 * Exit: double Shift again (only if headroom available).
 *
 * Entry: on ground, double Shift, headroom available
 * Behavior: low pose, speed reduced (crawlSpeedMultiplier)
 * Jump disabled while crawling
 */
public final class CrawlClient {

    private CrawlClient() {}

    /**
     * Toggle crawl on/off.
     * Called from ClientMovementService.toggleCrawl() via MovementInputService.
     */
    public static void toggle(ClientPlayerEntity player) {
        if (ClientMovementState.isCrawling()) {
            stopCrawl(player);
        } else {
            startCrawl(player);
        }
    }

    /**
     * Try to start crawling.
     */
    public static void startCrawl(ClientPlayerEntity player) {
        ShinobiCoreConfig.CrawlSection cfg = ShinobiCoreConfig.getInstance().crawl;
        if (!cfg.enabled) return;

        // Must be on ground
        if (cfg.requireOnGround && !player.isOnGround()) return;

        // Must not be in active phase (slide, roll, wall, etc.)
        MovementPhase phase = ClientMovementState.getPhase();
        if (phase != MovementPhase.NORMAL) return;

        // Start crawling
        ClientMovementState.setPhase(MovementPhase.CRAWLING);
        ClientMovementState.setCrawling(true);

        // Set low pose
        player.setPose(EntityPose.SWIMMING);

        // Send packet
        ClientMovementService.sendAction(player, MovementActionType.CRAWL_START);
    }

    /**
     * Try to stop crawling.
     * Only stops if headroom is available.
     */
    public static void stopCrawl(ClientPlayerEntity player) {
        if (!ClientMovementState.isCrawling()) return;

        // Check headroom: is there space to stand up?
        if (!hasHeadroom(player)) {
            // Can't stand up - stay crawling
            return;
        }

        // Stop crawling
        ClientMovementState.setPhase(MovementPhase.NORMAL);
        ClientMovementState.setCrawling(false);

        // Restore standing pose
        player.setPose(EntityPose.STANDING);

        // Send packet
        ClientMovementService.sendAction(player, MovementActionType.CRAWL_STOP);
    }

    /**
     * Tick crawl logic.
     * Called from ClientMovementService.tickCrawl().
     */
    public static void tick(ClientPlayerEntity player) {
        ShinobiCoreConfig.CrawlSection cfg = ShinobiCoreConfig.getInstance().crawl;

        // Maintain low pose
        if (player.getPose() != EntityPose.SWIMMING) {
            player.setPose(EntityPose.SWIMMING);
        }

        // Reduce speed
        Vec3d vel = player.getVelocity();
        double speed = Math.sqrt(vel.x * vel.x + vel.z * vel.z);
        if (speed > 0.01) {
            double maxSpeed = cfg.speedMultiplier * 0.1; // Base walk speed ~0.1
            if (speed > maxSpeed) {
                double scale = maxSpeed / speed;
                player.setVelocity(vel.x * scale, vel.y, vel.z * scale);
                player.velocityModified = true;
            }
        }
    }

    /**
     * Check if there is headroom to stand up.
     */
    private static boolean hasHeadroom(ClientPlayerEntity player) {
        BlockPos headPos = player.getBlockPos().up();
        return player.getWorld().getBlockState(headPos).isAir()
            || !player.getWorld().getBlockState(headPos).isSolidBlock(
                player.getWorld(), headPos);
    }

    public static boolean isCrawling() {
        return ClientMovementState.isCrawling();
    }
}