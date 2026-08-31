package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementPose;

public final class ClientMovementState {
    private static MovementPose currentPose = MovementPose.NORMAL;
    private static int wallRunCooldown = 0;
    private static int doubleJumpCharges = 1;
    private static int iFrames = 0;
    private static long lastSneakPress = 0;

    private ClientMovementState() {}

    public static MovementPose getPose() { return currentPose; }
    public static void setPose(MovementPose pose) { currentPose = pose; }
    
    public static int getWallRunCooldown() { return wallRunCooldown; }
    public static void setWallRunCooldown(int ticks) { wallRunCooldown = ticks; }
    
    public static int getDoubleJumpCharges() { return doubleJumpCharges; }
    public static void setDoubleJumpCharges(int c) { doubleJumpCharges = c; }

    public static int getIFrames() { return iFrames; }
    public static void setIFrames(int ticks) { iFrames = ticks; }

    public static long getLastSneakPress() { return lastSneakPress; }
    public static void setLastSneakPress(long time) { lastSneakPress = time; }

    public static void tickCooldowns() {
        if (wallRunCooldown > 0) wallRunCooldown--;
        if (iFrames > 0) iFrames--;
    }

    public static void reset() {
        currentPose = MovementPose.NORMAL;
        wallRunCooldown = 0;
        doubleJumpCharges = 1;
        iFrames = 0;
        lastSneakPress = 0;
    }
}