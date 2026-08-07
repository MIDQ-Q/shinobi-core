package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.NinjaFormula;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.fluid.FluidState;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

public class ChakraPhysicsClient {

    private static int logTimer = 0;
    private static boolean prevJumping = false;
    private static boolean wasOnGround = true;
    private static int airJumpsUsed = 0;
    private static int vaultCooldown = 0;
    private static int wallJumpCooldown = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraPhysicsClient::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        boolean chakraOn = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        boolean canParkour = ChakraHudRenderer.currentChakra > 0 && !ChakraHudRenderer.exhausted;
        boolean doLog = (logTimer == 0);

        World world = player.getWorld();
        BlockPos feet = player.getBlockPos();

        // === ДЕТЕКЦИЯ ОТРЫВА ОТ ЗЕМЛИ: сброс воздушных прыжков ===
        if (wasOnGround && !player.isOnGround()) {
            airJumpsUsed = 0;
        }
        wasOnGround = player.isOnGround();

        boolean jumpEdge = player.input.jumping && !prevJumping;
        prevJumping = player.input.jumping;

        if (vaultCooldown > 0) vaultCooldown--;
        if (wallJumpCooldown > 0) wallJumpCooldown--;

        // === ПРЫЖКИ В ВОЗДУХЕ (только если не на земле) ===
        if (canParkour && jumpEdge && !player.isOnGround()) {
            if (isNearWall(player) && wallJumpCooldown == 0) {
                // Прыжок от стены: слабый, с кулдауном
                Vec3d normal = wallNormal(player);
                player.addVelocity(normal.x * 0.25, 0.3, normal.z * 0.25);
                player.velocityModified = true;
                wallJumpCooldown = 10;
                sendParkour(1);
                if (doLog) ShinobiCore.LOGGER.info("[parkour] wall jump");
            } else if (!isNearWall(player) && airJumpsUsed < 1) {
                // Двойной прыжок: один раз в воздухе, вдали от стен
                player.addVelocity(0, 0.42, 0);
                player.velocityModified = true;
                airJumpsUsed = 1;
                sendParkour(0);
                if (doLog) ShinobiCore.LOGGER.info("[parkour] double jump");
            }
        }

        // === VAULT: авто-забор на 1 блок при спринте ===
        if (canParkour && vaultCooldown == 0 && player.isOnGround() && player.isSprinting() && player.horizontalCollision) {
            BlockPos ahead = feet.offset(player.getHorizontalFacing());
            boolean step = world.getBlockState(ahead).isSolidBlock(world, ahead)
                && world.getBlockState(ahead.up()).isAir();
            if (step) {
                player.addVelocity(0, 0.42, 0);
                player.velocityModified = true;
                vaultCooldown = 10;
                sendParkour(2);
                if (doLog) ShinobiCore.LOGGER.info("[parkour] vault");
            }
        }

        // === ВОДА И СТЕНЫ (только в чакра-режиме) ===
        if (chakraOn) {
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
                // === ВОДА ===
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
            } else if (!player.isOnGround() && isNearWall(player)) {
                // === СТЕНЫ: стабильная проверка блока рядом ===
                float vy;
                if (player.input.sneaking) {
                    vy = -0.05f; // медленный спуск
                } else if (player.input.pressingForward || player.input.jumping) {
                    vy = 0.05f; // медленный подъём
                } else {
                    vy = 0f; // зависание
                }

                // Не гасим импульс сразу после прыжка от стены
                if (wallJumpCooldown <= 5) {
                    Vec3d v = player.getVelocity();
                    player.setVelocity(v.x, vy, v.z);
                    player.fallDistance = 0f;
                }
                if (doLog) ShinobiCore.LOGGER.info("[chakra-wall] vy={}", vy);
            }
        }

        logTimer = (logTimer + 1) % 20;
    }

    private static void applyJumpBoost(ClientPlayerEntity player, boolean chakraOn) {
        int jumpLevel = ClientNinjaState.jumpLevel;
        float horizMult = NinjaFormula.jumpHorizontalMultiplier(jumpLevel, chakraOn);
        if (horizMult <= 1.0f) return;

        Vec3d velocity = player.getVelocity();
        double horizSpeed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
        if (horizSpeed < 0.01) return;

        double boost = (horizMult - 1.0) * horizSpeed;
        player.addVelocity(velocity.x / horizSpeed * boost, 0, velocity.z / horizSpeed * boost);

        if (chakraOn) {
            float vertMult = NinjaFormula.jumpVerticalMultiplier(jumpLevel, true);
            if (vertMult > 1.0f) player.addVelocity(0, 0.42 * (vertMult - 1.0), 0);
            if (player.isSprinting()) {
                player.addVelocity(0, 0.3, 0);
                player.addVelocity(velocity.x * 0.5, 0, velocity.z * 0.5);
            }
        }
        player.velocityModified = true;
    }

    private static boolean isNearWall(ClientPlayerEntity player) {
        World world = player.getWorld();
        BlockPos pos = player.getBlockPos();
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
        for (int dy = 0; dy <= 1; dy++) {
            for (int[] d : dirs) {
                BlockPos c = pos.add(d[0], dy, d[1]);
                if (world.getBlockState(c).isSolidBlock(world, c)) return true;
            }
        }
        return false;
    }

    private static Vec3d wallNormal(ClientPlayerEntity player) {
        World world = player.getWorld();
        BlockPos pos = player.getBlockPos();
        double nx = 0, nz = 0;
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
        for (int[] d : dirs) {
            BlockPos c = pos.add(d[0], 0, d[1]);
            if (world.getBlockState(c).isSolidBlock(world, c)) { nx -= d[0]; nz -= d[1]; }
        }
        double len = Math.sqrt(nx * nx + nz * nz);
        return len > 0 ? new Vec3d(nx / len, 0, nz / len) : new Vec3d(0, 0, 0);
    }

    private static void sendParkour(int type) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(type);
        ClientPlayNetworking.send(ModPackets.PARKOUR_ACTION_ID, buf);
    }

    private static String fmt(double d) { return String.format("%.2f", d); }
}