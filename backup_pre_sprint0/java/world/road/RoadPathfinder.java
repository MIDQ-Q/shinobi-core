package com.example.shinobicore.world.road;

import com.example.shinobicore.config.RoadConfig;
import net.minecraft.block.BlockState;
import net.minecraft.block.Blocks;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Direction;
import java.util.*;

/**
 * S8-02/S8-03: A* pathfinder with terrain cost weights.
 * Finds optimal road path between two village anchors.
 */
public class RoadPathfinder {
    
    private static final int MAX_ITERATIONS = 10000;
    
    public static List<BlockPos> findPath(ServerWorld world, VillageAnchor start, VillageAnchor end) {
        RoadConfig cfg = RoadConfig.instance;
        if (!cfg.enabled) return Collections.emptyList();
        
        Map<BlockPos, Node> openSet = new HashMap<>();
        Map<BlockPos, Node> closedSet = new HashMap<>();
        PriorityQueue<Node> queue = new PriorityQueue<>(Comparator.comparingDouble(n -> n.fScore));
        
        Node startNode = new Node(start.pos(), 0, heuristic(start.pos(), end.pos()));
        openSet.put(start.pos(), startNode);
        queue.add(startNode);
        
        int iterations = 0;
        while (!queue.isEmpty() && iterations < MAX_ITERATIONS) {
            iterations++;
            Node current = queue.poll();
            
            if (current.pos.equals(end.pos())) {
                return reconstructPath(current);
            }
            
            closedSet.put(current.pos, current);
            openSet.remove(current.pos);
            
            for (Direction dir : new Direction[]{Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST}) {
                BlockPos neighbor = current.pos.offset(dir);
                
                // Skip if already evaluated
                if (closedSet.containsKey(neighbor)) continue;
                
                // Calculate movement cost based on terrain
                float moveCost = getTerrainCost(world, current.pos, neighbor, cfg);
                if (moveCost < 0) continue; // Impassable
                
                double tentativeG = current.gScore + moveCost;
                Node existing = openSet.get(neighbor);
                
                if (existing == null || tentativeG < existing.gScore) {
                    Node newNode = new Node(neighbor, tentativeG, heuristic(neighbor, end.pos()));
                    newNode.parent = current;
                    openSet.put(neighbor, newNode);
                    queue.add(newNode);
                }
            }
        }
        
        // Fallback: direct line if A* fails
        if (cfg.generateFallback) {
            return generateFallbackPath(start.pos(), end.pos());
        }
        return Collections.emptyList();
    }
    
    /**
     * S8-03: Terrain cost calculation.
     * Returns -1 if impassable, otherwise positive cost.
     */
    private static float getTerrainCost(ServerWorld world, BlockPos from, BlockPos to, RoadConfig cfg) {
        BlockState state = world.getBlockState(to);
        BlockState below = world.getBlockState(to.down());
        
        // Water handling (S8-05)
        if (state.isOf(Blocks.WATER) || below.isOf(Blocks.WATER)) {
            // Check width for bridge vs bypass decision
            int waterWidth = measureWaterWidth(world, to);
            if (waterWidth <= cfg.bridgeMaxWidth) {
                return cfg.waterCost * 0.5f; // Bridge is cheaper than bypass
            } else {
                return cfg.waterCost * 3.0f; // Bypass is expensive, prefer going around
            }
        }
        
        // Slope detection
        int heightDiff = Math.abs(to.getY() - from.getY());
        if (heightDiff > 2) return -1; // Too steep
        if (heightDiff == 1) return cfg.slopeCost;
        
        // Structure avoidance
        if (!state.isAir() && !state.isOf(Blocks.GRASS_BLOCK) && !state.isOf(Blocks.DIRT) 
            && !state.isOf(Blocks.STONE) && !state.isOf(Blocks.SAND)) {
            return cfg.structureAvoidCost;
        }
        
        return 1.0f; // Flat ground
    }
    
    private static int measureWaterWidth(ServerWorld world, BlockPos center) {
        int width = 0;
        for (int d = -10; d <= 10; d++) {
            if (world.getBlockState(center.east(d)).isOf(Blocks.WATER)) width++;
        }
        return width;
    }
    
    private static double heuristic(BlockPos a, BlockPos b) {
        return Math.sqrt(a.getSquaredDistance(b));
    }
    
    private static List<BlockPos> reconstructPath(Node end) {
        List<BlockPos> path = new ArrayList<>();
        Node current = end;
        while (current != null) {
            path.add(current.pos);
            current = current.parent;
        }
        Collections.reverse(path);
        return path;
    }
    
    /**
     * S8-07: Simple fallback path (straight line with basic terrain following).
     */
    private static List<BlockPos> generateFallbackPath(BlockPos start, BlockPos end) {
        List<BlockPos> path = new ArrayList<>();
        BlockPos current = start;
        int maxSteps = (int) start.getSquaredDistance(end) * 2;
        
        for (int i = 0; i < maxSteps; i++) {
            path.add(current);
            if (current.equals(end)) break;
            
            double dx = end.getX() - current.getX();
            double dz = end.getZ() - current.getZ();
            
            if (Math.abs(dx) > Math.abs(dz)) {
                current = current.add(dx > 0 ? 1 : -1, 0, 0);
            } else {
                current = current.add(0, 0, dz > 0 ? 1 : -1);
            }
        }
        return path;
    }
    
    private static class Node {
        final BlockPos pos;
        double gScore;
        final double fScore;
        Node parent;
        
        Node(BlockPos pos, double g, double h) {
            this.pos = pos;
            this.gScore = g;
            this.fScore = g + h;
        }
    }
}