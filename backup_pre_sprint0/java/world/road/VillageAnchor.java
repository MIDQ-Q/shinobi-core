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