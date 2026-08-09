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
import net.minecraft.world.World;

public class ChakraPhysicsClient {

    private static int logTimer = 0;
    private static boolean prevJumping = false;
    private static boolean wasOnGround = true;
    private static int airJumpsUsed = 0;
    private static boolean wasStickingToWall = false;
    private static int wallJumpCooldown = 0; // кулдаун wall jump

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraPhysicsClient::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        boolean chakraOn = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        boolean canParkour = ChakraHudRenderer.currentChakra > 0 && !ChakraHudRenderer.exhausted;
        boolean doLog = (logTimer == 0);

        if (wasOnGround && !player.isOnGround()) airJumpsUsed = 0;
        wasOnGround = player.isOnGround();

        boolean jumpEdge = player.input.jumping && !prevJumping;
        prevJumping = player.input.jumping;

        if (wallJumpCooldown > 0) wallJumpCooldown--;

        ParkourManager.tick(client);
        if (ParkourManager.isSliding()) {
            logTimer = (logTimer + 1) % 20;
            return;
        }

        // === ДВОЙНОЙ ПРЫЖОК (не во время roll) ===
        if (canParkour && jumpEdge && !player.isOnGround() && airJumpsUsed < 1 && !ParkourManager.isRolling()) {
            player.addVelocity(0, 0.42, 0);
            player.velocityModified = true;
            airJumpsUsed = 1;
            if (doLog) ShinobiCore.LOGGER.info("[parkour] double jump");
        }

        // === ВОДА И СТЕНЫ ===
        if (chakraOn) {
            World world = player.getWorld();
            BlockPos feet = player.getBlockPos();

            double surfaceY = Double.NaN;
            for (int dy = 0; dy <= 3; dy++) {
                FluidState fs = world.getFluidState(feet.down(dy));
                if (!fs.isEmpty()) {
                    double h = fs.getHeight(world, feet.down(dy));
                    surfaceY = feet.down(dy).getY() + (h > 0 ? h : 1.0);
                    break;
                }
            }

            if (!Double.isNaN(surfaceY)) {
                Vec3d v = player.getVelocity();
                if (player.isSubmergedInWater()) {
                    player.setVelocity(v.x, 0.3, v.z);
                } else {
                    if (player.getY() < surfaceY - 0.001) {
                        player.setPosition(player.getX(), surfaceY, player.getZ());
                        v = player.getVelocity();
                    }
                    boolean nearSurface = player.getY() <= surfaceY + 0.05;
                    if (nearSurface) {
                        if (v.y < 0) player.setVelocity(v.x, 0.0, v.z);
                        player.setOnGround(true);
                        if (player.input.pressingForward && !player.input.sneaking && !player.isSprinting()) {
                            player.setSprinting(true);
                        }
                    }
                    if (doLog) ShinobiCore.LOGGER.info("[chakra-water] y={} surfaceY={}", fmt(player.getY()), fmt(surfaceY));
                }
                player.fallDistance = 0f;
                } else if (!player.isOnGround() && !ParkourManager.isWallRunning() && !ParkourManager.isEdgeGrabbing()) {
                // === WALL SLIDE ===
                Vec3d wallNormal = WallDetector.getWallNormal(player);
                boolean stickingNow = wallNormal != null;

                // === WALL JUMP: Space в wall slide ===
                if (stickingNow && jumpEdge && wallJumpCooldown == 0) {
                    // Отскок от стены: нормаль стены * 0.3 + вверх 0.35
                    Vec3d jumpVel = wallNormal.multiply(0.3).add(0, 0.35, 0);
                    player.addVelocity(jumpVel.x, jumpVel.y, jumpVel.z);
                    player.velocityModified = true;
                    wallJumpCooldown = 8; // 0.4 сек кулдаун
                    airJumpsUsed = 0; // после wall jump можно сделать ещё один двойной прыжок
                    wasStickingToWall = false;
                    ParkourSounds.playWallStick();
                    if (doLog) ShinobiCore.LOGGER.info("[parkour] wall jump");
                    logTimer = (logTimer + 1) % 20;
                    return; // пропускаем wall slide в этом тике
                }

                if (stickingNow && !wasStickingToWall) {
                    ParkourSounds.playWallStick();
                    if (doLog) ShinobiCore.LOGGER.info("[chakra-wall] stuck to wall");
                }
                wasStickingToWall = stickingNow;

                if (stickingNow) {
                    Vec3d v = player.getVelocity();

                    // === AUTO-VAULT: подъём на крышу при достижении края ===
                    if (player.input.pressingForward || player.input.jumping) {
                        BlockPos ledge = WallDetector.getLedgeAbove(player);
                        if (ledge != null) {
                            // Телепортируем на крышу (1 блок вверх)
                            player.setPosition(player.getX(), ledge.getY() + 0.001, player.getZ());
                            player.setVelocity(v.x * 0.5, 0.0, v.z * 0.5);
                            player.setOnGround(true);
                            wasStickingToWall = false;
                            ParkourSounds.playEdgeClimb();
                            if (doLog) ShinobiCore.LOGGER.info("[parkour] ledge climb");
                            logTimer = (logTimer + 1) % 20;
                            return;
                        }
                    }

                    // Плавное прилипание
                    double dotProduct = v.x * wallNormal.x + v.z * wallNormal.z;
                    if (dotProduct < 0) {
                        v = v.subtract(wallNormal.multiply(dotProduct));
                    }

                    float vy;
                    if (player.input.sneaking) {
                        vy = -0.05f;
                    } else if (player.input.pressingForward || player.input.jumping) {
                        vy = 0.05f;
                    } else {
                        vy = 0f;
                    }

                    player.setVelocity(v.x, vy, v.z);
                    player.fallDistance = 0f;
                }
            } else {
                wasStickingToWall = false;
            }
        } else {
            wasStickingToWall = false;
        }

        logTimer = (logTimer + 1) % 20;
    }

    private static String fmt(double d) { return String.format("%.2f", d); }
}