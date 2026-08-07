package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.fluid.FluidState;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

public class ChakraPhysicsClient {

    private static int logTimer = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraPhysicsClient::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;
        if (!ClientNinjaState.chakraMode || ChakraHudRenderer.currentChakra <= 0) return;

        boolean doLog = (logTimer == 0);
        World world = player.getWorld();
        BlockPos feet = player.getBlockPos();

        // === ПОИСК ПОВЕРХНОСТИ ВОДЫ (сканируем до 3 блоков вниз) ===
        double surfaceY = Double.NaN;
        for (int dy = 0; dy <= 3; dy++) {
            BlockPos check = feet.down(dy);
            FluidState fs = world.getFluidState(check);
            if (!fs.isEmpty()) {
                double h = fs.getHeight(world, check);
                surfaceY = check.getY() + (h > 0 ? h : 1.0);
                break;
            }
        }

        // === ХОДЬБА ПО ВОДЕ ===
        if (!Double.isNaN(surfaceY)) {
            Vec3d v = player.getVelocity();

            if (player.isSubmergedInWater()) {
                // Глубоко под водой — выталкиваем на поверхность
                player.setVelocity(v.x, 0.3, v.z);
                if (doLog) ShinobiCore.LOGGER.info("[chakra-water] submerged, push up. y={}", fmt(player.getY()));
            } else {
                // Провалился ниже поверхности — выталкиваем на неё
                if (player.getY() < surfaceY - 0.001) {
                    player.setPosition(player.getX(), surfaceY, player.getZ());
                    v = player.getVelocity();
                }

                boolean nearSurface = player.getY() <= surfaceY + 0.05;
                if (nearSurface) {
                    // Стоим на поверхности: не даём провалиться, но НЕ мешаем прыжку
                    if (v.y < 0) {
                        player.setVelocity(v.x, 0.0, v.z);
                    }
                    player.setOnGround(true);

                    // === ПРИНУДИТЕЛЬНЫЙ ПРЫЖОК (Space) ===
                    if (player.input.jumping && player.getVelocity().y <= 0.01) {
                        player.jump();
                        if (doLog) ShinobiCore.LOGGER.info("[chakra-water] JUMP! vy={}", fmt(player.getVelocity().y));
                    }

                    // === ПРИНУДИТЕЛЬНЫЙ СПРИНТ (W + Ctrl) ===
                    if (player.input.pressingForward && !player.input.sneaking && !player.isSprinting()) {
                        player.setSprinting(true);
                        if (doLog) ShinobiCore.LOGGER.info("[chakra-water] SPRINT on");
                    }
                }
                // Выше поверхности (в прыжке) — ничего не трогаем, работает баллистика

                if (doLog) ShinobiCore.LOGGER.info("[chakra-water] y={} surfaceY={} onGround={}",
                    fmt(player.getY()), fmt(surfaceY), player.isOnGround());
            }
            player.fallDistance = 0f;
        }

        // === ХОДЬБА ПО СТЕНАМ ===
        else if (player.horizontalCollision && !player.isOnGround()) {
            float vy;
            boolean up = player.input.pressingForward || player.input.jumping;
            if (up) {
                vy = 0.15f;
            } else if (player.input.sneaking) {
                vy = -0.15f;
            } else {
                vy = 0f;
            }
            Vec3d v = player.getVelocity();
            player.setVelocity(v.x, vy, v.z);
            player.fallDistance = 0f;
            if (doLog) ShinobiCore.LOGGER.info("[chakra-wall] vy={} up={} down={}", vy, up, player.input.sneaking);
        }

        logTimer = (logTimer + 1) % 20;
    }

    private static String fmt(double d) {
        return String.format("%.2f", d);
    }
}