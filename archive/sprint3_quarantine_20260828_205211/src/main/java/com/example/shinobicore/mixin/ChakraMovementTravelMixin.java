// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.mixin;

import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.client.ClientMovementService;
import com.example.shinobicore.movement.client.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * SHINOBICORE MOVEMENT V3 - Soft movement correction mixin.
 *
 * CRITICAL RULES:
 * - Injection point: TAIL only (after vanilla logic completes)
 * - NEVER use HEAD + cancellable (this broke wall walk in v2)
 * - NEVER call ci.cancel()
 * - NEVER setPosition() unless absolutely critical
 * - ONLY modify velocity and fallDistance softly
 * - SKIP if: player is in vehicle, flying in creative, dead, or movement disabled
 *
 * This mixin runs on BOTH client and server:
 * - Client: applies soft corrections (water, wall, slide, etc.)
 * - Server: only if serverMirrorPhysics is enabled (default: false)
 */
@Mixin(LivingEntity.class)
public abstract class ChakraMovementTravelMixin {

    /**
     * Injected AFTER vanilla travel() completes.
     * At this point vanilla physics have already run.
     * We only ADD soft corrections on top.
     */
    @Inject(method = "travel", at = @At("TAIL"))
    private void shinobicore_softMovementCorrection(Vec3d movementInput, CallbackInfo ci) {
        // Must be a LivingEntity - cast safely
        LivingEntity self = (LivingEntity) (Object) this;

        // Only process players
        if (!(self instanceof ClientPlayerEntity player)) {
            return;
        }

        // Must be client-side
        World world = player.getWorld();
        if (world == null || !world.isClient()) {
            return;
        }

        // Check global movement enabled flag
        ShinobiCoreConfig cfg = ShinobiCoreConfig.getInstance();
        if (!cfg.movement.enabled) {
            return;
        }

        // Skip if player is in invalid state
        if (player.isDead()) return;
        if (player.hasVehicle()) return;
        if (player.getAbilities().flying) return;
        if (player.isSpectator()) return;

        // Get current phase
        MovementPhase phase = ClientMovementState.getPhase();

        // If in NORMAL phase and no active corrections needed, skip
        if (phase == MovementPhase.NORMAL) {
            return;
        }

        // === SOFT CORRECTIONS BY PHASE ===
        // Scripts 08-11 will fill these in.
        // For now, only reset fallDistance for active phases.

        switch (phase) {
            case WATER_WALKING -> {
                // Stabilize player on water surface
                player.fallDistance = 0f;

                // Prevent sinking
                Vec3d velocity = player.getVelocity();
                if (velocity.y < 0 && !player.isSneaking()) {
                    // Reduce downward velocity to prevent sinking
                    double newY = Math.max(velocity.y, -0.08);
                    player.setVelocity(velocity.x, newY, velocity.z);
                }

                // Snap to water surface if slightly below
                com.example.shinobicore.movement.client.WaterDetector detector = null;
                double waterY = com.example.shinobicore.movement.client.WaterDetector.getWaterSurfaceY(player);
                if (waterY > 0) {
                    double feetY = player.getY();
                    double delta = feetY - waterY;
                    ShinobiCoreConfig.WaterWalkSection waterCfg = ShinobiCoreConfig.getInstance().waterWalk;

                    if (delta < -waterCfg.surfaceLowerTolerance && delta > -0.5) {
                        // Player is slightly below surface - push up gently
                        Vec3d vel = player.getVelocity();
                        player.setVelocity(vel.x, 0.1, vel.z);
                    }
                }
            }
            case WALL_RUNNING -> {
                // Wall run: reduce gravity, prevent falling, soft stick
                player.fallDistance = 0f;

                Vec3d wallNormal = com.example.shinobicore.movement.client.ClientMovementState.getWallNormal();
                if (wallNormal != null) {
                    // Soft stick: if drifting away from wall, gently pull back
                    Vec3d vel = player.getVelocity();
                    double awayFromWall = vel.x * wallNormal.x + vel.z * wallNormal.z;
                    if (awayFromWall > 0.02) {
                        // Drifting away - reduce outward velocity
                        double correction = awayFromWall * 0.5;
                        player.setVelocity(
                            vel.x - wallNormal.x * correction,
                            vel.y,
                            vel.z - wallNormal.z * correction
                        );
                    }
                }
            }
            case SLIDING -> {
                // Slide: maintain low pose and boost
                player.fallDistance = 0f;
                // Keep pose low
                if (player.getPose() != net.minecraft.entity.EntityPose.SWIMMING) {
                    player.setPose(net.minecraft.entity.EntityPose.SWIMMING);
                }
            }
            case CRAWLING -> {
                // Crawl: reduce speed, maintain low pose
                player.fallDistance = 0f;
                if (player.getPose() != net.minecraft.entity.EntityPose.SWIMMING) {
                    player.setPose(net.minecraft.entity.EntityPose.SWIMMING);
                }
                // Speed reduction is handled in CrawlClient.tick()
            }
            case ROLLING -> {
                // Roll: maintain low pose, reduce fall damage
                player.fallDistance = 0f;
                if (player.getPose() != net.minecraft.entity.EntityPose.SWIMMING) {
                    player.setPose(net.minecraft.entity.EntityPose.SWIMMING);
                }
            }
            case DODGING -> {
                // Dodge: i-frames, reduce fall damage
                player.fallDistance = 0f;
            }
            case CHARGING_JUMP -> {
                // Slow down player while charging
                Vec3d vel = player.getVelocity();
                player.setVelocity(vel.x * 0.7, vel.y, vel.z * 0.7);
                player.velocityModified = true;
            }
            case EDGE_GRABBING -> {
                // Hang on ledge: cancel gravity
                player.fallDistance = 0f;
                Vec3d vel = player.getVelocity();
                player.setVelocity(vel.x, -0.01, vel.z);
                player.velocityModified = true;
            }
            case MEDITATING -> {
                // Meditation: enforce stillness
                player.fallDistance = 0f;
                
                // Apply slowness to prevent accidental movement
                Vec3d vel = player.getVelocity();
                player.setVelocity(vel.x * 0.1, vel.y, vel.z * 0.1);
                player.velocityModified = true;
            }
            default -> {
                // NORMAL or unknown - do nothing
            }
        }
    }
}