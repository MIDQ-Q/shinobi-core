package com.example.shinobicore.client.physics;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.client.parkour.util.WallDetector;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

public final class WallStickHandler {
    private static boolean wasStickingToWall = false;

    private WallStickHandler() {}

    public static void tick(MinecraftClient client, ClientPlayerEntity player) {
        PhysicsState.standingOnWater = false;
        Vec3d wallNormal = WallDetector.getWallNormal(player);
        boolean stickingNow = wallNormal != null;
        boolean jumpEdge = player.input.jumping && !PhysicsState.prevJumping();

        if (stickingNow && jumpEdge && PhysicsState.getWallJumpCooldown() == 0) {
            Vec3d jumpVel = wallNormal.multiply(0.3).add(0, 0.35, 0);
            player.addVelocity(jumpVel.x, jumpVel.y, jumpVel.z);
            player.velocityModified = true;
            PhysicsState.setWallJumpCooldown(8);
            PhysicsState.resetAirJumps();
            wasStickingToWall = false;
            ParkourSounds.playWallStick();
            return;
        }

        if (stickingNow && !wasStickingToWall) {
            ParkourSounds.playWallStick();
        }
        wasStickingToWall = stickingNow;
        PhysicsState.stickingToWall = stickingNow;

        if (stickingNow) {
            Vec3d v = player.getVelocity();
            BlockPos ledge = WallDetector.getLedgeAbove(player);
            if (ledge != null && (player.input.pressingForward || player.input.jumping)) {
                player.setPosition(player.getX(), ledge.getY() + 0.001, player.getZ());
                player.setVelocity(v.x * 0.5, 0.0, v.z * 0.5);
                player.setOnGround(true);
                wasStickingToWall = false;
                ParkourSounds.playEdgeClimb();
                return;
            }
            double dotProduct = v.x * wallNormal.x + v.z * wallNormal.z;
            if (dotProduct < 0) {
                v = v.subtract(wallNormal.multiply(dotProduct));
            }
            float vy;
            if (player.input.sneaking) vy = -0.05f;
            else if (player.input.pressingForward || player.input.jumping) vy = 0.05f;
            else vy = 0f;
            player.setVelocity(v.x, vy, v.z);
            player.fallDistance = 0f;
        }
    }

    public static void reset() {
        wasStickingToWall = false;
    }
}