package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.client.util.WallDetector;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class WallRunService {
    private static boolean wasRunning = false;
    private static Vec3d currentNormal = null;
    private static int runTicks = 0;
    private static int debugLogCounter = 0;

    private WallRunService() {}

    public static void tick(ClientPlayerEntity player) {
        if (player == null) return;
        if (player.getWorld() == null) return;
        if (!player.getWorld().isClient) return;

        if (!MovementConfig.ENABLED) {
            if (wasRunning) stopWallRun(player);
            return;
        }

        if (player.isOnGround()) {
            if (wasRunning) stopWallRun(player);
            return;
        }

        Vec3d normal = WallDetector.getWallNormal(player);
        if (normal == null) {
            if (wasRunning) stopWallRun(player);
            return;
        }

        if (runTicks >= 60) {
            if (wasRunning) stopWallRun(player);
            return;
        }

        if (!wasRunning) {
            startWallRun(player, normal);
        }
        currentNormal = normal;
        runTicks++;

        Vec3d vel = player.getVelocity();
        if (vel.y < 0) {
            player.setVelocity(vel.x, vel.y * MovementConfig.WALL_RUN_GRAVITY_MULT, vel.z);
        }

        debugLogCounter++;
        if (debugLogCounter >= 40) {
            debugLogCounter = 0;
            ShinobiLogger.module("movement", "WallRun active: ticks=" + runTicks);
        }
    }

    private static void startWallRun(ClientPlayerEntity player, Vec3d normal) {
        wasRunning = true;
        runTicks = 0;
        currentNormal = normal;
        ShinobiLogger.module("movement", "WallRun STARTED");
    }

    private static void stopWallRun(ClientPlayerEntity player) {
        if (wasRunning) {
            ShinobiLogger.module("movement", "WallRun STOPPED after " + runTicks + " ticks");
        }
        wasRunning = false;
        currentNormal = null;
        runTicks = 0;
    }

    public static boolean isRunning() { return wasRunning; }
    public static Vec3d getCurrentNormal() { return currentNormal; }
    public static void reset() {
        wasRunning = false;
        currentNormal = null;
        runTicks = 0;
        debugLogCounter = 0;
    }
}