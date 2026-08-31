// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.ShinobiCoreConfig;
import net.minecraft.block.BlockState;
import net.minecraft.block.Blocks;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.fluid.FluidState;
import net.minecraft.fluid.Fluids;
import net.minecraft.registry.tag.FluidTags;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

/**
 * Detects if player is standing on water surface.
 * Uses configurable tolerances for surface detection.
 */
public final class WaterDetector {

    private WaterDetector() {}

    /**
     * Check if player is on water surface (within tolerance).
     * Returns true if:
     * - Player's feet are within surfaceLowerTolerance below water surface
     * - Player's feet are within surfaceUpperTolerance above water surface
     * - Block below is water (or waterlogged/bubble column if enabled)
     */
    public static boolean isOnWaterSurface(ClientPlayerEntity player) {
        if (player == null) return false;

        World world = player.getWorld();
        if (world == null) return false;

        ShinobiCoreConfig.WaterWalkSection cfg = ShinobiCoreConfig.getInstance().waterWalk;
        if (!cfg.enabled) return false;

        Vec3d pos = player.getPos();
        double feetY = pos.y; // Bottom of player hitbox

        // Check block directly below feet
        BlockPos belowPos = BlockPos.ofFloored(pos.x, feetY - 0.1, pos.z);
        BlockState belowState = world.getBlockState(belowPos);
        FluidState belowFluid = belowState.getFluidState();

        // Check if block below is water
        boolean isWaterBelow = false;

        if (belowFluid.isIn(FluidTags.WATER)) {
            isWaterBelow = true;
        } else if (cfg.allowWaterlogged && belowState.isOf(Blocks.WATER)) {
            isWaterBelow = true;
        } else if (cfg.allowBubbleColumn && belowState.isOf(Blocks.BUBBLE_COLUMN)) {
            isWaterBelow = true;
        }

        if (!isWaterBelow) return false;

        // Get water surface Y (top of water block)
        double waterSurfaceY = belowPos.getY() + 1.0;

        // Check if player is within tolerance range
        double delta = feetY - waterSurfaceY;

        return delta >= -cfg.surfaceLowerTolerance && delta <= cfg.surfaceUpperTolerance;
    }

    /**
     * Check if player is fully submerged in water.
     */
    public static boolean isSubmerged(ClientPlayerEntity player) {
        if (player == null) return false;

        World world = player.getWorld();
        if (world == null) return false;

        // Check if player's eyes are in water
        return player.isSubmergedIn(FluidTags.WATER);
    }

    /**
     * Check if player is touching water (feet or lower body).
     */
    public static boolean isTouchingWater(ClientPlayerEntity player) {
        if (player == null) return false;
        return player.isTouchingWater();
    }

    /**
     * Get the water surface Y coordinate at player's position.
     * Returns -1 if no water found.
     */
    public static double getWaterSurfaceY(ClientPlayerEntity player) {
        if (player == null) return -1;

        World world = player.getWorld();
        if (world == null) return -1;

        Vec3d pos = player.getPos();
        BlockPos belowPos = BlockPos.ofFloored(pos.x, pos.y - 0.1, pos.z);
        BlockState belowState = world.getBlockState(belowPos);
        FluidState belowFluid = belowState.getFluidState();

        if (belowFluid.isIn(FluidTags.WATER) || belowState.isOf(Blocks.WATER)) {
            return belowPos.getY() + 1.0;
        }

        return -1;
    }
}