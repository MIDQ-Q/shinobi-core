package com.example.shinobicore.modules.movement.client.input;

import com.example.shinobicore.modules.movement.client.*;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

public final class MovementInputHandler {
    private static boolean jumpWasPressed = false;
    private static boolean sneakWasPressed = false;

    private MovementInputHandler() {}

    public static void handleInput(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        boolean jumpPressed = client.options.jumpKey.isPressed();
        boolean sneakPressed = client.options.sneakKey.isPressed();

        // --- Jump Logic ---
        if (jumpPressed && !jumpWasPressed) {
            if (ClientMovementState.getPose() == MovementPose.WALL_RUNNING) {
                WallJumpService.tryJump(player);
            } else if (!player.isOnGround() && player.getVelocity().y >= 0) {
                DoubleJumpService.tryJump(player);
            } else if (player.isOnGround() && player.getVelocity().horizontalLengthSquared() < 0.01) {
                ChargedJumpService.startCharge(player);
            }
        }
        
        if (!jumpPressed && jumpWasPressed) {
            ChargedJumpService.releaseJump(player);
        }
        jumpWasPressed = jumpPressed;

        // --- Sneak Logic ---
        if (sneakPressed && !sneakWasPressed) {
            long now = System.currentTimeMillis();
            if (ClientMovementState.getPose() == MovementPose.EDGE_GRABBING) {
                EdgeGrabService.drop(player);
            } else if (player.isOnGround() && player.getVelocity().horizontalLengthSquared() < 0.05) {
                if (now - ClientMovementState.getLastSneakPress() < 250) {
                    CrawlService.toggle(player);
                    ClientMovementState.setLastSneakPress(0);
                } else {
                    ClientMovementState.setLastSneakPress(now);
                }
            } else if (player.isSprinting()) {
                SlideService.start(player);
            }
        }
        sneakWasPressed = sneakPressed;

        // --- Keybinds ---
        if (MovementKeyBindings.ROLL_KEY.wasPressed()) {
            RollService.start(player);
        }
        if (MovementKeyBindings.DODGE_KEY.wasPressed()) {
            DodgeService.start(player);
        }
        
        // --- Edge Grab Climb ---
        if (jumpPressed && ClientMovementState.getPose() == MovementPose.EDGE_GRABBING) {
            EdgeGrabService.climb(player);
        }
    }
}