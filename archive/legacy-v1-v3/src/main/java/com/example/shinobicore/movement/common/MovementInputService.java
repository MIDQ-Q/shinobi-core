package com.example.shinobicore.movement.common;

import net.minecraft.client.network.ClientPlayerEntity;

public final class MovementInputService {
    private static boolean jumpPressedLastTick = false;
    private static boolean jumpPressedThisTick = false;

    public static void update(ClientPlayerEntity player) {
        jumpPressedLastTick = jumpPressedThisTick;
        jumpPressedThisTick = player.input.jumping;
    }

    public static boolean wasJumpPressed() {
        return jumpPressedThisTick && !jumpPressedLastTick;
    }

    public static boolean isJumpHeld() {
        return jumpPressedThisTick;
    }

    public static boolean isSneaking(ClientPlayerEntity player) {
        return player.input.sneaking;
    }

    public static boolean isMovingForward(ClientPlayerEntity player) {
        return player.input.pressingForward;
    }

    public static boolean isMoving(ClientPlayerEntity player) {
        return player.input.pressingForward || player.input.pressingBack 
            || player.input.pressingLeft || player.input.pressingRight;
    }

    public static float getForwardInput(ClientPlayerEntity player) {
        return player.input.movementForward;
    }

    public static float getStrafeInput(ClientPlayerEntity player) {
        return player.input.movementSideways;
    }
}