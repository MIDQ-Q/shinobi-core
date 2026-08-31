package com.example.shinobicore.modules.movement.client.anim;

import com.example.shinobicore.modules.movement.client.ClientMovementState;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import net.minecraft.client.network.ClientPlayerEntity;

/**
 * Bridges MovementPose to visual/animation states.
 * In a full implementation, this would call PlayerAnimator API.
 * For now, it manages vanilla pose overrides and prepares data for rendering.
 */
public final class ParkourAnimationController {
    private static MovementPose lastRenderedPose = MovementPose.NORMAL;

    private ParkourAnimationController() {}

    public static void tick(ClientPlayerEntity player) {
        MovementPose currentPose = ClientMovementState.getPose();
        
        if (currentPose == lastRenderedPose) return;
        lastRenderedPose = currentPose;

        // Apply vanilla overrides / trigger PlayerAnimator events
        switch (currentPose) {
            case WATER_WALKING:
                // Trigger water walk animation (arms slightly raised)
                break;
            case WALL_RUNNING:
                // Trigger wall run animation (tilted)
                break;
            case SLIDING:
            case CRAWLING:
                player.setSwimming(true);
                break;
            case ROLLING:
                // Trigger roll animation
                break;
            case DODGING:
                // Trigger dodge blur/shift
                break;
            case CHARGING_JUMP:
                // Trigger crouch charge
                break;
            case EDGE_GRABBING:
                // Trigger hang animation
                break;
            case NORMAL:
            default:
                if (currentPose != MovementPose.SLIDING && currentPose != MovementPose.CRAWLING) {
                    player.setSwimming(false);
                }
                break;
        }
    }

    public static boolean isNarutoRunning(ClientPlayerEntity player) {
        if (!MovementConfig.NARUTO_RUN_ENABLED) return false;
        if (!player.isSprinting()) return false;
        
        float speed = (float) player.getVelocity().horizontalLength();
        return speed >= MovementConfig.NARUTO_RUN_MIN_SPEED && 
               ClientMovementState.getPose() == MovementPose.NORMAL;
    }
}