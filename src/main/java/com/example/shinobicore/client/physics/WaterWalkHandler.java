package com.example.shinobicore.client.physics;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.fluid.FluidState;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

public final class WaterWalkHandler {
    private WaterWalkHandler() {}

    public static void tick(MinecraftClient client, ClientPlayerEntity player) {
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
            Vec3d v = player.getVelocity();
            if (player.isSubmergedInWater()) {
                player.setVelocity(v.x, 0.3, v.z);
                PhysicsState.standingOnWater = false;
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
                        PhysicsState.standingOnWater = true;
                    } else {
                        PhysicsState.standingOnWater = false;
                    }
                    if (player.input.pressingForward && !player.input.sneaking && !player.isSprinting()) {
                        player.setSprinting(true);
                    }
                } else {
                    PhysicsState.standingOnWater = false;
                }
            }
            player.fallDistance = 0f;
        } else {
            PhysicsState.standingOnWater = false;
        }
    }
}