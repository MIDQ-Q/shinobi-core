package com.example.shinobicore.client;
import com.example.shinobicore.util.DebugTraceLogger;

import com.example.shinobicore.client.parkour.util.WallDetector;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.fluid.FluidState;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

/**
 * Client-authoritative physics for Chakra Mode parkour (v1.0 logic adapted for v2.0).
 * Water walking + Wall sticking.
 *
 * Architecture: Client directly controls velocity, server only validates.
 */
public class ChakraPhysicsClient {
    private static int airJumpsUsed = 0;
    public static boolean standingOnWater = false;
    private static boolean stickingToWall = false;
    private static boolean wasStickingToWall = false;
    private static int wallJumpCooldown = 0;
    private static boolean wasJumping = false;
    private static int logTimer = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraPhysicsClient::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        // Chakra Mode check (CLIENT state, not server component)
        boolean chakraMode = ClientNinjaState.chakraMode;
        boolean hasChakra = NinjaComponents.getChakra(player) != null && NinjaComponents.getChakra(player).getCurrentChakra() > 0;

        DebugTraceLogger.check("CHAKRA_MODE", chakraMode, "HasChakra: " + hasChakra);
        if (!chakraMode || !hasChakra) {
            wasStickingToWall = false;
            stickingToWall = false;
            standingOnWater = false;
            return;
        }

        // Cooldowns
        if (wallJumpCooldown > 0) wallJumpCooldown--;

        // Jump edge detection
        boolean jumping = player.input.jumping;
        boolean jumpEdge = jumping && !wasJumping;
        wasJumping = jumping;

        logTimer = (logTimer + 1) % 200;
        boolean doLog = (logTimer == 0);

        // === WATER DETECTION ===
        BlockPos feet = player.getBlockPos();
        double surfaceY = Double.NaN;
        for (int dy = 0; dy <= 3; dy++) {
            FluidState fs = player.getWorld().getFluidState(feet.down(dy));
            if (!fs.isEmpty()) {
                double h = fs.getHeight(player.getWorld(), feet.down(dy));
                surfaceY = feet.down(dy).getY() + (h > 0 ? h : 1.0);
                break;
            }
        }

        DebugTraceLogger.check("WATER_SURFACE", !Double.isNaN(surfaceY), "Y: " + surfaceY);
        if (!Double.isNaN(surfaceY)) {
            // === WATER WALKING ===
            Vec3d v = player.getVelocity();
            if (player.isSubmergedInWater()) {
                player.setVelocity(v.x, 0.3, v.z);
                standingOnWater = false;
            } else {
                if (player.getY() < surfaceY - 0.001) {
                    player.setPosition(player.getX(), surfaceY, player.getZ());
                    v = player.getVelocity();
                }
                boolean nearSurface = player.getY() <= surfaceY + 0.05;
                if (nearSurface) {
                    if (v.y < 0) {
                        player.setVelocity(v.x, 0.0, v.z);
                        v = player.getVelocity();
                    }
                    boolean isJumpingUp = v.y > 0.1;
                    if (!isJumpingUp) {
                        player.setOnGround(true);
                        standingOnWater = true;
                    } else {
                        standingOnWater = false;
                    }
                    if (player.input.pressingForward && !player.input.sneaking && !player.isSprinting()) {
                        player.setSprinting(true);
                    }
                } else {
                    standingOnWater = false;
                }
            }
            player.fallDistance = 0f;
        } else if (!player.isOnGround()) {
            // === WALLS (v1 STABLE PHYSICS) ===
            standingOnWater = false;
            Vec3d wallNormal = com.example.shinobicore.client.parkour.util.WallDetector.getWallNormal(player);
            boolean stickingNow = wallNormal != null;

            // Wall jump
            if (stickingNow && jumpEdge && wallJumpCooldown == 0) {
                Vec3d jumpVel = wallNormal.multiply(0.3).add(0, 0.35, 0);
                player.addVelocity(jumpVel.x, jumpVel.y, jumpVel.z);
                player.velocityModified = true;
                wallJumpCooldown = 8;
                airJumpsUsed = 0;
                wasStickingToWall = false;
                com.example.shinobicore.client.parkour.util.ParkourSounds.playWallStick();
                if (doLog) com.example.shinobicore.ShinobiCore.LOGGER.debug("[parkour] wall jump");
                logTimer = (logTimer + 1) % 20;
                return;
            }

            if (stickingNow && !wasStickingToWall) {
                com.example.shinobicore.client.parkour.util.ParkourSounds.playWallStick();
                if (doLog) com.example.shinobicore.ShinobiCore.LOGGER.debug("[chakra-wall] stuck to wall");
            }

            wasStickingToWall = stickingNow;
            stickingToWall = stickingNow;

            if (stickingNow) {
                Vec3d v = player.getVelocity();

                // Auto ledge climb
                BlockPos ledge = com.example.shinobicore.client.parkour.util.WallDetector.getLedgeAbove(player);
                if (ledge != null && (player.input.pressingForward || player.input.jumping)) {
                    player.setPosition(player.getX(), ledge.getY() + 0.001, player.getZ());
                    player.setVelocity(v.x * 0.5, 0.0, v.z * 0.5);
                    player.setOnGround(true);
                    wasStickingToWall = false;
                    com.example.shinobicore.client.parkour.util.ParkourSounds.playEdgeClimb();
                    if (doLog) com.example.shinobicore.ShinobiCore.LOGGER.debug("[parkour] ledge climb");
                    logTimer = (logTimer + 1) % 20;
                    return;
                }

                // Smooth sticking (cancel velocity into wall)
                double dotProduct = v.x * wallNormal.x + v.z * wallNormal.z;
                if (dotProduct < 0) {
                    v = v.subtract(wallNormal.multiply(dotProduct));
                }

                // Vertical speed limit
                float vy;
                if (player.input.sneaking) vy = -0.05f;
                else if (player.input.pressingForward || player.input.jumping) vy = 0.05f;
                else vy = 0f;

                player.setVelocity(v.x, vy, v.z);
                player.fallDistance = 0f;
            }
        } else {
            wasStickingToWall = false;
            standingOnWater = false;
        }
    }
}