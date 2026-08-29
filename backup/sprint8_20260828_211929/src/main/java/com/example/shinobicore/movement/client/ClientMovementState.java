// SHINOBICORE:SPRINT6:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 6 client-side movement state holder.
 */
public final class ClientMovementState {
    private static MovementPhase phase = MovementPhase.NORMAL;
    private static int ticksInPhase = 0;

    private static boolean onWater = false;
    private static boolean onWall = false;
    private static boolean isCrawling = false;
    private static boolean isSliding = false;
    private static boolean isMeditating = false;

    private static int airJumpsUsed = 0;
    private static int sequenceNumber = 0;

    private static Vec3d wallNormal = null;
    private static int jumpGraceTicks = 0;
    private static int wallCooldownTicks = 0;
    private static int maxAirJumps = 1;

    private ClientMovementState() {}

    public static MovementPhase getPhase() {
        return phase;
    }

    public static int getTicksInPhase() {
        return ticksInPhase;
    }

    public static boolean isOnWater() {
        return onWater;
    }

    public static boolean isOnWall() {
        return onWall;
    }

    public static boolean isCrawling() {
        return isCrawling;
    }

    public static boolean isSliding() {
        return isSliding;
    }

    public static boolean isMeditating() {
        return isMeditating;
    }

    public static int getAirJumpsUsed() {
        return airJumpsUsed;
    }

    public static int getMaxAirJumps() {
        return maxAirJumps;
    }

    public static Vec3d getWallNormal() {
        return wallNormal;
    }

    public static int getJumpGraceTicks() {
        return jumpGraceTicks;
    }

    public static int getWallCooldownTicks() {
        return wallCooldownTicks;
    }

    public static int getSequenceNumber() {
        return sequenceNumber;
    }

    public static void setPhase(MovementPhase newPhase) {
        if (phase != newPhase) {
            phase = newPhase;
            ticksInPhase = 0;
        }
    }

    public static void setOnWater(boolean value) {
        onWater = value;
    }

    public static void setOnWall(boolean value) {
        onWall = value;
    }

    public static void setCrawling(boolean value) {
        isCrawling = value;
    }

    public static void setSliding(boolean value) {
        isSliding = value;
    }

    public static void setMeditating(boolean value) {
        isMeditating = value;
    }

    public static void setAirJumpsUsed(int value) {
        airJumpsUsed = value;
    }

    public static void setMaxAirJumps(int value) {
        maxAirJumps = value;
    }

    public static void setWallNormal(Vec3d normal) {
        wallNormal = normal;
    }

    public static void setJumpGraceTicks(int value) {
        jumpGraceTicks = Math.max(0, value);
    }

    public static void setWallCooldownTicks(int value) {
        wallCooldownTicks = Math.max(0, value);
    }

    public static void tick() {
        ticksInPhase++;

        if (jumpGraceTicks > 0) {
            jumpGraceTicks--;
        }

        if (wallCooldownTicks > 0) {
            wallCooldownTicks--;
        }
    }

    public static int nextSequence() {
        return ++sequenceNumber;
    }

    public static void resetAll() {
        phase = MovementPhase.NORMAL;
        ticksInPhase = 0;
        onWater = false;
        onWall = false;
        isCrawling = false;
        isSliding = false;
        isMeditating = false;
        airJumpsUsed = 0;
        wallNormal = null;
        jumpGraceTicks = 0;
        wallCooldownTicks = 0;
    }
}