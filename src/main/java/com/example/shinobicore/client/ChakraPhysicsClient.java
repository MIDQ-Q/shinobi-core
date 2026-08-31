package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.client.parkour.util.WallDetector;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.fluid.FluidState;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

public class ChakraPhysicsClient {

    private static int logTimer = 0;
    private static boolean prevJumping = false;
    private static int airJumpsUsed = 0;
    private static boolean wasStickingToWall = false;
    public static boolean stickingToWall = false;
    private static int wallJumpCooldown = 0;
    private static boolean wasOnGroundOrWater = true;

    // Флаг "стоит на воде" — обновляется в onClientTick, читается в mixin и ChargedJumpAction
    public static boolean standingOnWater = false;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraPhysicsClient::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        boolean chakraOn = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        boolean canParkour = ChakraHudRenderer.currentChakra > 0 && !ChakraHudRenderer.exhausted;
        boolean doLog = (logTimer == 0);

        // Состояние "на земле или воде" — из прошлого тика
        boolean onGroundOrWater = player.isOnGround() || standingOnWater;

        // Сброс airJumpsUsed при сходе с земли/воды
        if (wasOnGroundOrWater && !onGroundOrWater) {
            airJumpsUsed = 0;
        }
        wasOnGroundOrWater = onGroundOrWater;

        // Edge detection для Space
        boolean jumpEdge = player.input.jumping && !prevJumping;
        prevJumping = player.input.jumping;

        if (wallJumpCooldown > 0) wallJumpCooldown--;

        // === ПАРКУР ===
        ParkourManager.tick(client);
        if (ParkourManager.isSliding()) {
            logTimer = (logTimer + 1) % 20;
            return;
        }

        // === DOUBLE JUMP (только если НЕ на земле/воде) ===
        if (canParkour && jumpEdge && !onGroundOrWater && airJumpsUsed < 1) {
            player.addVelocity(0, 0.42, 0);
            player.velocityModified = true;
            airJumpsUsed = 1;
            if (doLog) ShinobiCore.LOGGER.debug("[parkour] double jump");
        }

        // === WATER + WALL PHYSICS ===
        if (chakraOn) {
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

            if (!Double.isNaN(surfaceY)) {
                // === ВОДА ===
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
                            // Гасим падение только если игрок падает
                            player.setVelocity(v.x, 0.0, v.z);
                            v = player.getVelocity();
                        }
                        // КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ:
                        // Не устанавливаем setOnGround если игрок прыгает вверх.
                        // Иначе в следующем тике mixin отменит повторный прыжок с воды.
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
                    if (doLog) ShinobiCore.LOGGER.debug("[chakra-water] y={} surfaceY={}", fmt(player.getY()), fmt(surfaceY));
                }
                player.fallDistance = 0f;
            } else if (!player.isOnGround() && !ParkourManager.isWallRunning()) {
                // === СТЕНЫ ===
                standingOnWater = false;
                Vec3d wallNormal = WallDetector.getWallNormal(player);
                boolean stickingNow = wallNormal != null;

                // Wall jump
                if (stickingNow && jumpEdge && wallJumpCooldown == 0) {
                    Vec3d jumpVel = wallNormal.multiply(0.3).add(0, 0.35, 0);
                    player.addVelocity(jumpVel.x, jumpVel.y, jumpVel.z);
                    player.velocityModified = true;
                    wallJumpCooldown = 8;
                    airJumpsUsed = 0;
                    wasStickingToWall = false;
                    ParkourSounds.playWallStick();
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] wall jump");
                    logTimer = (logTimer + 1) % 20;
                    return;
                }

                if (stickingNow && !wasStickingToWall) {
                    ParkourSounds.playWallStick();
                    if (doLog) ShinobiCore.LOGGER.debug("[chakra-wall] stuck to wall");
                }
                wasStickingToWall = stickingNow;
            stickingToWall = stickingNow;

                if (stickingNow) {
                    Vec3d v = player.getVelocity();

                    // Auto ledge climb
                    BlockPos ledge = WallDetector.getLedgeAbove(player);
                    if (ledge != null && (player.input.pressingForward || player.input.jumping)) {
                        player.setPosition(player.getX(), ledge.getY() + 0.001, player.getZ());
                        player.setVelocity(v.x * 0.5, 0.0, v.z * 0.5);
                        player.setOnGround(true);
                        wasStickingToWall = false;
                        ParkourSounds.playEdgeClimb();
                        if (doLog) ShinobiCore.LOGGER.debug("[parkour] ledge climb");
                        logTimer = (logTimer + 1) % 20;
                        return;
                    }

                    // Плавное прилипание
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
            } else {
                wasStickingToWall = false;
                standingOnWater = false;
            }
        } else {
            wasStickingToWall = false;
            standingOnWater = false;
        }

        logTimer = (logTimer + 1) % 20;
    }

    private static String fmt(double d) { return String.format("%.2f", d); }
}