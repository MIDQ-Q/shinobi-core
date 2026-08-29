// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.common;

import com.example.shinobicore.config.ShinobiCoreConfig;
import net.minecraft.block.BlockState;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.registry.tag.BlockTags;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;

/**
 * Detects walls suitable for wall running.
 * Checks at 3 heights: low, mid, high.
 * Respects config for allowed block types.
 */
public final class WallDetector {

    private WallDetector() {}

    /**
     * Raycast offsets for 3 height checks (relative to player eye).
     */
    private static final double[] HEIGHT_OFFSETS = {-0.3, 0.0, 0.3};

    /**
     * Find wall normal by raycasting in 4 horizontal directions.
     * Returns null if no valid wall found.
     */
    public static Vec3d getWallNormal(ClientPlayerEntity player) {
        ShinobiCoreConfig.WallRunSection cfg = ShinobiCoreConfig.getInstance().wallRun;
        if (!cfg.enabled) return null;

        World world = player.getWorld();
        if (world == null) return null;

        Vec3d eye = player.getEyePos();
        double dist = cfg.raycastDistance;

        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

        for (int[] d : dirs) {
            Vec3d dir = new Vec3d(d[0], 0, d[1]);

            // Check all 3 heights
            boolean allBlocked = true;
            for (double hOff : HEIGHT_OFFSETS) {
                Vec3d start = eye.add(0, hOff, 0);
                Vec3d end = start.add(dir.multiply(dist));

                BlockHitResult hit = world.raycast(new RaycastContext(
                    start, end,
                    RaycastContext.ShapeType.COLLIDER,
                    RaycastContext.FluidHandling.NONE,
                    player
                ));

                if (hit.getType() != HitResult.Type.BLOCK) {
                    allBlocked = false;
                    break;
                }

                BlockPos hitPos = hit.getBlockPos();
                if (!isAllowedWallBlock(world, hitPos)) {
                    allBlocked = false;
                    break;
                }
            }

            if (allBlocked) {
                // Normal points AWAY from wall (toward player)
                return new Vec3d(-d[0], 0, -d[1]);
            }
        }

        return null;
    }

    /**
     * Get the block position of the detected wall.
     * Returns null if no wall found.
     */
    public static BlockPos getWallBlockPos(ClientPlayerEntity player) {
        ShinobiCoreConfig.WallRunSection cfg = ShinobiCoreConfig.getInstance().wallRun;
        if (!cfg.enabled) return null;

        World world = player.getWorld();
        if (world == null) return null;

        Vec3d eye = player.getEyePos();
        double dist = cfg.raycastDistance;

        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

        for (int[] d : dirs) {
            Vec3d dir = new Vec3d(d[0], 0, d[1]);
            Vec3d end = eye.add(dir.multiply(dist));

            BlockHitResult hit = world.raycast(new RaycastContext(
                eye, end,
                RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE,
                player
            ));

            if (hit.getType() == HitResult.Type.BLOCK) {
                BlockPos hitPos = hit.getBlockPos();
                if (isAllowedWallBlock(world, hitPos)) {
                    return hitPos;
                }
            }
        }

        return null;
    }

    /**
     * Check if a block is allowed as a wall surface.
     */
    public static boolean isAllowedWallBlock(World world, BlockPos pos) {
        ShinobiCoreConfig.WallBlocksSection cfg = ShinobiCoreConfig.getInstance().wallBlocks;
        BlockState state = world.getBlockState(pos);

        // Blacklist check
        String blockId = getBlockId(state);
        if (cfg.blacklistIds != null) {
            for (String bl : cfg.blacklistIds) {
                if (blockId.equals(bl)) return false;
            }
        }

        // Extra IDs check
        if (cfg.extraIds != null) {
            for (String extra : cfg.extraIds) {
                if (blockId.equals(extra)) return true;
            }
        }

        // Must have collision (not air, not decorative without collision)
        if (!state.getCollisionShape(world, pos).isEmpty()) {
            // Solid full blocks
            if (cfg.allowSolidBlocks && state.isSolidBlock(world, pos)) {
                return true;
            }

            // Walls (#minecraft:walls)
            if (cfg.allowWalls && state.isIn(BlockTags.WALLS)) {
                return true;
            }

            // Fences (#minecraft:fences)
            if (cfg.allowFences && state.isIn(BlockTags.FENCES)) {
                return true;
            }

            // Glass (#minecraft:impermeable)
            if (cfg.allowGlass && state.isIn(BlockTags.IMPERMEABLE)) {
                return true;
            }

            // Leaves (#minecraft:leaves)
            if (cfg.allowLeaves && state.isIn(BlockTags.LEAVES)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Check for corner conflict (player near two perpendicular walls).
     * If two walls meet at a corner, wall running can be unstable.
     * Returns true if there IS a conflict.
     */
    public static boolean isCornerConflict(ClientPlayerEntity player) {
        World world = player.getWorld();
        if (world == null) return false;

        Vec3d eye = player.getEyePos();
        double dist = ShinobiCoreConfig.getInstance().wallRun.raycastDistance;

        int wallCount = 0;
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

        for (int[] d : dirs) {
            Vec3d dir = new Vec3d(d[0], 0, d[1]);
            Vec3d end = eye.add(dir.multiply(dist));

            BlockHitResult hit = world.raycast(new RaycastContext(
                eye, end,
                RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE,
                player
            ));

            if (hit.getType() == HitResult.Type.BLOCK &&
                isAllowedWallBlock(world, hit.getBlockPos())) {
                wallCount++;
            }
        }

        // Corner = 2 perpendicular walls
        return wallCount >= 2;
    }

    /**
     * Check if player is moving toward the wall.
     * Returns true if velocity has significant component toward wall.
     */
    public static boolean isMovingTowardWall(ClientPlayerEntity player, Vec3d wallNormal) {
        if (wallNormal == null) return false;

        Vec3d vel = player.getVelocity();
        // Dot product: negative means moving toward wall
        // (normal points away from wall)
        double dot = vel.x * wallNormal.x + vel.z * wallNormal.z;

        // Must be moving INTO the wall (negative dot = toward wall)
        return dot < -0.05;
    }

    private static String getBlockId(BlockState state) {
        return net.minecraft.registry.Registries.BLOCK.getId(state.getBlock()).toString();
    }
}