package com.example.shinobicore.world.road;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.RoadConfig;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;
import java.util.*;

/**
 * S8-02/S8-09: Manages the road graph between villages.
 * Connects nearest neighbors, validates connectivity.
 */
public class RoadNetworkManager {
    
    private static final Map<BlockPos, List<BlockPos>> ROAD_GRAPH = new HashMap<>();
    
    /**
     * Generate roads for all known village anchors.
     */
    public static void generateRoads(ServerWorld world, List<VillageAnchor> anchors) {
        RoadConfig cfg = RoadConfig.instance;
        if (!cfg.enabled) {
            ShinobiCore.LOGGER.info("[ROADS] Road generation disabled by config");
            return;
        }
        
        ShinobiCore.LOGGER.info("[ROADS] Generating roads for {} anchors", anchors.size());
        ROAD_GRAPH.clear();
        
        // S8-02: Connect each anchor to its nearest neighbor(s)
        for (VillageAnchor anchor : anchors) {
            VillageAnchor nearest = findNearest(anchor, anchors);
            if (nearest != null && !nearest.equals(anchor)) {
                connectAnchors(world, anchor, nearest);
            }
        }
        
        // S8-09: Validate connectivity
        validateConnectivity(anchors);
    }
    
    private static VillageAnchor findNearest(VillageAnchor source, List<VillageAnchor> all) {
        VillageAnchor best = null;
        double bestDist = Double.MAX_VALUE;
        
        for (VillageAnchor other : all) {
            if (other.equals(source)) continue;
            double dist = source.pos().getSquaredDistance(other.pos());
            if (dist < bestDist) {
                bestDist = dist;
                best = other;
            }
        }
        return best;
    }
    
    private static void connectAnchors(ServerWorld world, VillageAnchor a, VillageAnchor b) {
        // Avoid duplicate connections
        if (ROAD_GRAPH.containsKey(a.pos()) && ROAD_GRAPH.get(a.pos()).contains(b.pos())) return;
        
        List<BlockPos> path = RoadPathfinder.findPath(world, a, b);
        if (!path.isEmpty()) {
            RoadBuilder.buildRoad(world, path, a);
            ROAD_GRAPH.computeIfAbsent(a.pos(), k -> new ArrayList<>()).add(b.pos());
            ROAD_GRAPH.computeIfAbsent(b.pos(), k -> new ArrayList<>()).add(a.pos());
            ShinobiCore.LOGGER.info("[ROADS] Connected {} -> {} ({} segments)", 
                a.pos().toShortString(), b.pos().toShortString(), path.size());
        } else {
            ShinobiCore.LOGGER.warn("[ROADS] Failed to connect {} -> {}", 
                a.pos().toShortString(), b.pos().toShortString());
        }
    }
    
    /**
     * S8-09: Validate that all villages are reachable.
     */
    private static void validateConnectivity(List<VillageAnchor> anchors) {
        if (anchors.isEmpty()) return;
        
        Set<BlockPos> visited = new HashSet<>();
        Queue<BlockPos> queue = new LinkedList<>();
        queue.add(anchors.get(0).pos());
        visited.add(anchors.get(0).pos());
        
        while (!queue.isEmpty()) {
            BlockPos current = queue.poll();
            List<BlockPos> neighbors = ROAD_GRAPH.getOrDefault(current, Collections.emptyList());
            for (BlockPos neighbor : neighbors) {
                if (!visited.contains(neighbor)) {
                    visited.add(neighbor);
                    queue.add(neighbor);
                }
            }
        }
        
        int connected = visited.size();
        int total = anchors.size();
        if (connected < total) {
            ShinobiCore.LOGGER.warn("[ROADS] Connectivity issue: {}/{} villages connected", connected, total);
        } else {
            ShinobiCore.LOGGER.info("[ROADS] All {} villages connected successfully", total);
        }
    }
    
    public static void clear() {
        ROAD_GRAPH.clear();
    }
}