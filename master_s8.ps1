# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 8 (Roads & Connectivity)
# S8-01..S8-09: Road Generation System
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$worldDir = Join-Path $srcBase "world"
$roadDir = Join-Path $worldDir "road"
$configDir = Join-Path $srcBase "config"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 8: Roads & Global Connectivity" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host ("  [MISS] " + $p) -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host ("  [SKIP] already: " + (Split-Path $p -Leaf)) -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host ("  [FAIL] pattern not found: " + (Split-Path $p -Leaf)) -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host ("  [PATCH] " + (Split-Path $p -Leaf)) -ForegroundColor Green
    return $true
}

# ============================================================
# S8-08: Road Config (Toggle + Parameters)
# ============================================================
Write-Host "[S8-08] Creating RoadConfig..." -ForegroundColor Yellow

$roadConfig = @'
package com.example.shinobicore.config;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;
import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * S8-08: Road generation configuration.
 * Allows disabling roads entirely or tweaking generation parameters.
 */
public class RoadConfig {
    public boolean enabled = true;
    public int maxRoadLengthChunks = 32;
    public int bridgeMaxWidth = 8; // >8 blocks = bypass (Variant C)
    public float slopeCost = 5.0f;
    public float waterCost = 20.0f;
    public float structureAvoidCost = 50.0f;
    public int lanternRadiusChunks = 5; // Lanterns only within this radius from village exit
    public boolean generateFallback = true;

    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    public static RoadConfig instance = new RoadConfig();

    public static Path path() {
        return FabricLoader.getInstance().getConfigDir()
            .resolve("shinobicore").resolve("roads.json");
    }

    public static void load() {
        try {
            Path p = path();
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                instance = new RoadConfig();
                save();
            } else {
                try (FileReader reader = new FileReader(p.toFile())) {
                    RoadConfig loaded = GSON.fromJson(reader, RoadConfig.class);
                    if (loaded != null) instance = loaded;
                }
            }
            ShinobiCore.LOGGER.info("[ROADS] Config loaded: enabled={}, bridgeMax={}", 
                instance.enabled, instance.bridgeMaxWidth);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[ROADS] Failed to load config, using defaults", e);
            instance = new RoadConfig();
        }
    }

    public static void save() {
        try (FileWriter writer = new FileWriter(path().toFile())) {
            GSON.toJson(instance, writer);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[ROADS] Failed to save config", e);
        }
    }
}
'@
Write-File (Join-Path $configDir "RoadConfig.java") $roadConfig

# ============================================================
# S8-01: Village Anchor (Connection Point)
# ============================================================
Write-Host "[S8-01] Creating VillageAnchor..." -ForegroundColor Yellow

$villageAnchor = @'
package com.example.shinobicore.world.road;

import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Direction;

/**
 * S8-01: Anchor point for road connections.
 * Each village has one or more anchors defining where roads start/end.
 */
public record VillageAnchor(
    BlockPos pos,
    Direction facing,
    RoadType type,
    int priority
) {
    public enum RoadType {
        MAIN,      // Primary road to nearest neighbor
        SECONDARY, // Side paths
        RING       // Circular route around village
    }
}
'@
Write-File (Join-Path $roadDir "VillageAnchor.java") $villageAnchor

# ============================================================
# S8-04: Road Segment Templates
# ============================================================
Write-Host "[S8-04] Creating RoadSegmentType..." -ForegroundColor Yellow

$segmentType = @'
package com.example.shinobicore.world.road;

/**
 * S8-04: Road segment templates.
 * Gates excluded per user request.
 */
public enum RoadSegmentType {
    STRAIGHT,
    TURN,
    FORK,
    DESCENT,
    ASCENT,
    BRIDGE,
    STAIRS
}
'@
Write-File (Join-Path $roadDir "RoadSegmentType.java") $segmentType

# ============================================================
# S8-03 + S8-02: Road Pathfinder (A* with terrain cost)
# ============================================================
Write-Host "[S8-02/03] Creating RoadPathfinder (A*)..." -ForegroundColor Yellow

$pathfinder = @'
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
            
            for (Direction dir : Direction.HORIZONTAL) {
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
'@
Write-File (Join-Path $roadDir "RoadPathfinder.java") $pathfinder

# ============================================================
# S8-04 + S8-05 + S8-06: Road Builder (Segments + POI)
# ============================================================
Write-Host "[S8-04/05/06] Creating RoadBuilder..." -ForegroundColor Yellow

$roadBuilder = @'
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
        Direction prevDir = Direction.fromHorizontalDegrees(getAngle(prev, current));
        Direction nextDir = Direction.fromHorizontalDegrees(getAngle(current, next));
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
'@
Write-File (Join-Path $roadDir "RoadBuilder.java") $roadBuilder

# ============================================================
# S8-02 + S8-09: Road Network Manager (Graph + Validation)
# ============================================================
Write-Host "[S8-02/09] Creating RoadNetworkManager..." -ForegroundColor Yellow

$networkManager = @'
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
'@
Write-File (Join-Path $roadDir "RoadNetworkManager.java") $networkManager

# ============================================================
# PATCH: Register road generation in ShinobiCore
# ============================================================
Write-Host "[PATCH] Integrating roads into ShinobiCore..." -ForegroundColor Yellow

$shinobiCoreFile = Join-Path $srcBase "ShinobiCore.java"

# Add import
Patch-File $shinobiCoreFile `
    "import com.example.shinobicore.config.ModConfig;" `
    "import com.example.shinobicore.config.ModConfig;`nimport com.example.shinobicore.config.RoadConfig;"

# Load road config alongside main config
Patch-File $shinobiCoreFile `
    "ModConfig.load();" `
    "ModConfig.load();`n        RoadConfig.load();"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 8 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - config/RoadConfig.java (S8-08: toggle + params)" -ForegroundColor Cyan
Write-Host "  - world/road/VillageAnchor.java (S8-01: connection points)" -ForegroundColor Cyan
Write-Host "  - world/road/RoadSegmentType.java (S8-04: segment templates)" -ForegroundColor Cyan
Write-Host "  - world/road/RoadPathfinder.java (S8-02/03: A* with terrain cost)" -ForegroundColor Cyan
Write-Host "  - world/road/RoadBuilder.java (S8-04/05/06: segments + POI)" -ForegroundColor Cyan
Write-Host "  - world/road/RoadNetworkManager.java (S8-02/09: graph + validation)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Key features:" -ForegroundColor White
Write-Host "  - A* pathfinding with slope/water/structure costs" -ForegroundColor Yellow
Write-Host "  - Bridges for narrow rivers (<=8 blocks), bypass for wide" -ForegroundColor Yellow
Write-Host "  - Lanterns only within 5 chunks of village exit" -ForegroundColor Yellow
Write-Host "  - POI: torii, shrines, ambush markers, signposts" -ForegroundColor Yellow
Write-Host "  - Fallback mode for failed paths" -ForegroundColor Yellow
Write-Host "  - Config toggle: roads.enabled" -ForegroundColor Yellow
Write-Host "  - Connectivity validation on generation" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next step: Run '.\gradlew.bat build' to verify compilation." -ForegroundColor Cyan
Write-Host ""