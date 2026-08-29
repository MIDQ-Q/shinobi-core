package com.example.shinobicore.world.road;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.RoadConfig;
import net.minecraft.block.Blocks;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Direction;
import java.util.List;

/**
 * S8-04/05/06: Builds road segments and places POIs along the path.
 * Handles bridges, stairs, lanterns, torii, shrines, ambush points.
 */
public class RoadBuilder {
    
    /**
     * Build a complete road from a list of positions.
     */
    public static void buildRoad(ServerWorld world, List<BlockPos> path, VillageAnchor anchor) {
        RoadConfig cfg = RoadConfig.instance;
        if (!cfg.enabled || path.isEmpty()) return;
        
        ShinobiCore.LOGGER.info("[ROADS] Building road with {} segments", path.size());
        
        for (int i = 0; i < path.size(); i++) {
            BlockPos pos = path.get(i);
            BlockPos prev = i > 0 ? path.get(i - 1) : pos;
            BlockPos next = i < path.size() - 1 ? path.get(i + 1) : pos;
            
            // Determine segment type
            RoadSegmentType type = determineSegmentType(prev, pos, next, world);
            
            // Build segment
            buildSegment(world, pos, type, prev, next);
            
            // Place POIs (S8-06)
            placePOIs(world, pos, i, path.size(), anchor, cfg);
        }
    }
    
    private static RoadSegmentType determineSegmentType(BlockPos prev, BlockPos current, BlockPos next, ServerWorld world) {
        // Height changes
        if (current.getY() > prev.getY()) return RoadSegmentType.ASCENT;
        if (current.getY() < prev.getY()) return RoadSegmentType.DESCENT;
        
        // Turns
        Direction prevDir = Direction.fromRotation(getAngle(prev, current));
        Direction nextDir = Direction.fromRotation(getAngle(current, next));
        if (prevDir != nextDir) return RoadSegmentType.TURN;
        
        // Water = bridge
        if (world.getBlockState(current.down()).isOf(Blocks.WATER)) return RoadSegmentType.BRIDGE;
        
        return RoadSegmentType.STRAIGHT;
    }
    
    private static void buildSegment(ServerWorld world, BlockPos pos, RoadSegmentType type, 
                                     BlockPos prev, BlockPos next) {
        switch (type) {
            case STRAIGHT -> buildStraight(world, pos);
            case TURN -> buildTurn(world, pos, prev, next);
            case ASCENT, DESCENT -> buildStairs(world, pos, type == RoadSegmentType.ASCENT);
            case BRIDGE -> buildBridge(world, pos);
            default -> buildStraight(world, pos);
        }
    }
    
    private static void buildStraight(ServerWorld world, BlockPos pos) {
        // Gravel path with cobblestone edges
        safeSetBlock(world, pos, Blocks.GRAVEL);
        safeSetBlock(world, pos.west(), Blocks.COBBLESTONE);
        safeSetBlock(world, pos.east(), Blocks.COBBLESTONE);
    }
    
    private static void buildTurn(ServerWorld world, BlockPos pos, BlockPos prev, BlockPos next) {
        safeSetBlock(world, pos, Blocks.GRAVEL);
        // Fill corners
        safeSetBlock(world, pos.west(), Blocks.COBBLESTONE);
        safeSetBlock(world, pos.east(), Blocks.COBBLESTONE);
        safeSetBlock(world, pos.north(), Blocks.COBBLESTONE);
        safeSetBlock(world, pos.south(), Blocks.COBBLESTONE);
    }
    
    private static void buildStairs(ServerWorld world, BlockPos pos, boolean ascending) {
        // Use cobblestone stairs based on direction
        safeSetBlock(world, pos, Blocks.COBBLESTONE_STAIRS);
    }
    
    private static void buildBridge(ServerWorld world, BlockPos pos) {
        // Wooden plank bridge over water
        safeSetBlock(world, pos, Blocks.OAK_PLANKS);
        // Fence rails on sides
        safeSetBlock(world, pos.west(), Blocks.OAK_FENCE);
        safeSetBlock(world, pos.east(), Blocks.OAK_FENCE);
        // Support pillars down to solid ground
        for (int y = -1; y >= -5; y--) {
            BlockPos support = pos.down(-y);
            if (world.getBlockState(support).isOf(Blocks.WATER) || world.getBlockState(support).isAir()) {
                safeSetBlock(world, support, Blocks.OAK_LOG);
            } else {
                break;
            }
        }
    }
    
    /**
     * S8-06: Place Points of Interest along the road.
     * Lanterns only within lanternRadiusChunks from village exit.
     */
    private static void placePOIs(ServerWorld world, BlockPos pos, int index, int totalLength, 
                                  VillageAnchor anchor, RoadConfig cfg) {
        // Distance from start in chunks
        double distChunks = index / 16.0;
        
        // Lanterns: only within configured radius from village exit
        if (distChunks <= cfg.lanternRadiusChunks && index % 16 == 0) {
            safeSetBlock(world, pos.up(), Blocks.LANTERN);
        }
        
        // Torii: at ~25% and ~75% of road length
        if (index == totalLength / 4 || index == totalLength * 3 / 4) {
            buildTorii(world, pos);
        }
        
        // Small shrine: at midpoint
        if (index == totalLength / 2) {
            buildSmallShrine(world, pos);
        }
        
        // Ambush point: random chance at ~60% mark
        if (index == totalLength * 3 / 5 && world.getRandom().nextFloat() < 0.3f) {
            // Mark as potential ambush zone (metadata/block marker)
            safeSetBlock(world, pos.up(2), Blocks.REDSTONE_TORCH); // Temporary marker
        }
        
        // Signpost at forks (if applicable)
        // Note: Fork detection would need enhanced path analysis
    }
    
    private static void buildTorii(ServerWorld world, BlockPos center) {
        // Simple torii gate structure
        safeSetBlock(world, center.west(2), Blocks.DARK_OAK_LOG);
        safeSetBlock(world, center.east(2), Blocks.DARK_OAK_LOG);
        safeSetBlock(world, center.west(2).up(), Blocks.DARK_OAK_LOG);
        safeSetBlock(world, center.east(2).up(), Blocks.DARK_OAK_LOG);
        safeSetBlock(world, center.west(3).up(2), Blocks.DARK_OAK_SLAB);
        safeSetBlock(world, center.east(3).up(2), Blocks.DARK_OAK_SLAB);
        safeSetBlock(world, center.up(2), Blocks.DARK_OAK_SLAB);
    }
    
    private static void buildSmallShrine(ServerWorld world, BlockPos center) {
        safeSetBlock(world, center, Blocks.STONE_BRICKS);
        safeSetBlock(world, center.up(), Blocks.STONE_BRICK_SLAB);
        safeSetBlock(world, center.up(2), Blocks.LANTERN);
    }
    
    private static void safeSetBlock(ServerWorld world, BlockPos pos, net.minecraft.block.Block block) {
        if (!world.getBlockState(pos).isOf(block)) {
            world.setBlockState(pos, block.getDefaultState(), 3);
        }
    }
    
    private static float getAngle(BlockPos from, BlockPos to) {
        double dx = to.getX() - from.getX();
        double dz = to.getZ() - from.getZ();
        return (float) Math.toDegrees(Math.atan2(dz, dx));
    }
}