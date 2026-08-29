// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ClientChakraController;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Vec3d;

/**
 * Slide mechanic: sprint + single Shift on ground -> forward boost.
 * In chakra mode: longer duration + stronger boost.
 *
 * Entry: on ground, sprinting, moving forward, single Shift
 * Behavior: impulse in look direction, low pose, timed duration
 * Cost: fatigue + chakra (if chakra mode)
 */
public final class SlideClient {

    private SlideClient() {}

    private static int slideTicksLeft = 0;

    /**
     * Try to start sliding.
     * Called from ClientMovementService.tryStartSlide() via MovementInputService.
     */
    public static boolean tryStart(ClientPlayerEntity player) {
        ShinobiCoreConfig.SlideSection cfg = ShinobiCoreConfig.getInstance().slide;
        if (!cfg.enabled) return false;

        // Must be on ground
        if (!player.isOnGround()) return false;

        // Must be sprinting and moving forward
        if (!player.isSprinting()) return false;
        if (player.input.movementForward <= 0) return false;

        // Must not already be in slide/crawl/other active phase
        MovementPhase phase = ClientMovementState.getPhase();
        if (phase != MovementPhase.NORMAL) return false;

        // Cooldown check
        if (ClientMovementState.getSlideCooldown() > 0) return false;

        // Chakra mode check (slide works without chakra mode but shorter)
        boolean chakraMode = ClientChakraController.isChakraModeActive();

        // Determine duration
        int duration = chakraMode ? cfg.durationChakra : cfg.durationNormal;

        // Cost
        float fatigueCost = cfg.fatigueCost;
        float chakraCost = cfg.chakraCost;

        // Pay costs
        ClientChakraController.addFatigue(fatigueCost);
        if (chakraMode) {
            if (!ClientChakraController.spendChakra(chakraCost)) {
                return false; // Can't afford
            }
        }

        // Start slide
        slideTicksLeft = duration;
        ClientMovementState.setPhase(MovementPhase.SLIDING);
        ClientMovementState.setSliding(true);
        ClientMovementState.setSlideCooldown(cfg.cooldownTicks);

        // Apply initial impulse
        float boost = chakraMode ? cfg.boostChakra : cfg.boostNormal;
        float rad = player.getYaw() * 0.017453292F;
        player.setVelocity(
            -Math.sin(rad) * boost,
            0.0,
            Math.cos(rad) * boost
        );
        player.velocityModified = true;

        // Set low pose
        player.setPose(EntityPose.SWIMMING);

        // Send packet
        ClientMovementService.sendAction(player, MovementActionType.SLIDE_START);

        return true;
    }

    /**
     * Tick slide logic.
     * Called from ClientMovementService.tickSlide().
     */
    public static void tick(ClientPlayerEntity player) {
        ShinobiCoreConfig.SlideSection cfg = ShinobiCoreConfig.getInstance().slide;

        slideTicksLeft--;

        // Check exit conditions
        if (slideTicksLeft <= 0) {
            stop(player);
            return;
        }

        // Stop if hit a wall (velocity near zero)
        Vec3d vel = player.getVelocity();
        double speed = Math.sqrt(vel.x * vel.x + vel.z * vel.z);
        if (speed < 0.05 && slideTicksLeft < (cfg.durationNormal - 3)) {
            stop(player);
            return;
        }

        // Stop if not on ground anymore
        if (!player.isOnGround()) {
            stop(player);
            return;
        }

        // Maintain low pose
        if (player.getPose() != EntityPose.SWIMMING) {
            player.setPose(EntityPose.SWIMMING);
        }

        // Apply slight friction
        player.setVelocity(vel.x * 0.92, vel.y, vel.z * 0.92);
        player.velocityModified = true;
    }

    /**
     * Stop sliding.
     */
    public static void stop(ClientPlayerEntity player) {
        if (ClientMovementState.getPhase() != MovementPhase.SLIDING) return;

        ClientMovementState.setPhase(MovementPhase.NORMAL);
        ClientMovementState.setSliding(false);
        slideTicksLeft = 0;

        // Restore standing pose
        player.setPose(EntityPose.STANDING);

        // Send packet
        ClientMovementService.sendAction(player, MovementActionType.SLIDE_STOP);
    }

    public static int getSlideTicksLeft() {
        return slideTicksLeft;
    }
}