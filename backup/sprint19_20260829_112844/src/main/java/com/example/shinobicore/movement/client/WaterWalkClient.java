// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.registry.tag.FluidTags;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 4 water walking subsystem.
 */
public final class WaterWalkClient {
    private static boolean active = false;

    private WaterWalkClient() {}

    public static boolean isActive() { return active; }

    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.waterWalk) {
            setActive(false);
            return;
        }

        if (!ChakraClientController.isChakraModeActive()) {
            setActive(false);
            return;
        }

        boolean onWaterSurface = isOnWaterSurface(player);

        if (onWaterSurface && !MovementInputService.isSneaking(player)) {
            if (!active) {
                setActive(true);
                ClientMovementState.setPhase(MovementPhase.WATER_WALKING);
            }

            // Drain chakra
            MovementChakraConfig config = MovementChakraConfig.getInstance();
            float drain = config.chakra.waterWalkDrainPerTick;
            ChakraClientController.consumeChakra(drain);

            // Stabilize: prevent sinking below water surface
            Vec3d vel = player.getVelocity();
            if (vel.y < 0.0) {
                player.setVelocity(vel.x, 0.0, vel.z);
                player.velocityModified = true;
            }

            // Prevent fall damage
            player.fallDistance = 0.0f;
        } else {
            if (active) {
                setActive(false);
                ClientMovementState.setPhase(MovementPhase.NORMAL);
            }
        }
    }

    private static boolean isOnWaterSurface(ClientPlayerEntity player) {
        BlockPos pos = player.getBlockPos();
        BlockPos below = pos.down();

        if (player.getWorld().getFluidState(below).isIn(FluidTags.WATER)) {
            double playerY = player.getY();
            double waterSurfaceY = below.getY() + 1.0;
            return Math.abs(playerY - waterSurfaceY) < 0.3;
        }

        return false;
    }

    private static void setActive(boolean value) { active = value; }
}