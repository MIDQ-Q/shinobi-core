package com.example.shinobicore.movement.common;
import net.minecraft.util.math.Vec3d;

public class ClientMovementState {
    private static MovementPhase phase = MovementPhase.NORMAL;
    private static int jumpsLeft = 3;
    private static int maxAirJumps = 2;
    private static int iframeTicks = 0;
    private static int wallCooldownTicks = 0;
    private static Vec3d wallNormal = null;
    private static boolean onWater = false;

    public static MovementPhase getPhase() { return phase; }
    public static void setPhase(MovementPhase p) { phase = p; }
    
    public static int getJumpsLeft() { return jumpsLeft; }
    public static void useAirJump() { if (jumpsLeft > 0) jumpsLeft--; }
    public static void resetAirJumps() { jumpsLeft = 3; }
    
    public static int getIframeTicks() { return iframeTicks; }
    public static void setIframeTicks(int t) { iframeTicks = t; }
    public static void tickIframes() { if (iframeTicks > 0) iframeTicks--; }
    public static boolean isInvulnerable() { return iframeTicks > 0; }
    
    public static int getWallCooldownTicks() { return wallCooldownTicks; }
    public static void setWallCooldownTicks(int t) { wallCooldownTicks = t; }
    public static void tickWallCooldown() { if (wallCooldownTicks > 0) wallCooldownTicks--; }
    
    public static Vec3d getWallNormal() { return wallNormal; }
    public static void setWallNormal(Vec3d n) { wallNormal = n; }
    
    public static boolean isOnWater() { return onWater; }
    public static void setOnWater(boolean b) { onWater = b; }
}