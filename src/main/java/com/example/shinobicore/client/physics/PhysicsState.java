package com.example.shinobicore.client.physics;

public final class PhysicsState {
    private PhysicsState() {}

    public static boolean stickingToWall = false;
    public static boolean standingOnWater = false;
    private static int airJumpsUsed = 0;
    private static int wallJumpCooldown = 0;
    private static boolean wasOnGroundOrWater = true;
    private static boolean prevJumping = false;

    public static int getAirJumpsUsed() { return airJumpsUsed; }
    public static void setAirJumpsUsed(int v) { airJumpsUsed = v; }
    public static void resetAirJumps() { airJumpsUsed = 0; }

    public static int getWallJumpCooldown() { return wallJumpCooldown; }
    public static void decrementWallJumpCooldown() { if (wallJumpCooldown > 0) wallJumpCooldown--; }
    public static void setWallJumpCooldown(int v) { wallJumpCooldown = v; }

    public static boolean wasOnGroundOrWater() { return wasOnGroundOrWater; }
    public static void setWasOnGroundOrWater(boolean v) { wasOnGroundOrWater = v; }

    public static boolean prevJumping() { return prevJumping; }
    public static void setPrevJumping(boolean v) { prevJumping = v; }

    public static void reset() {
        stickingToWall = false;
        standingOnWater = false;
        airJumpsUsed = 0;
        wallJumpCooldown = 0;
        wasOnGroundOrWater = true;
        prevJumping = false;
    }
}