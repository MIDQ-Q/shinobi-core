package com.example.shinobicore.world.structure;

import net.minecraft.block.BlockState;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class StructureBuilder {

    public static void fill(WorldAccess world, BlockPos from, BlockPos to, BlockState state) {
        int minX = Math.min(from.getX(), to.getX());
        int maxX = Math.max(from.getX(), to.getX());
        int minY = Math.min(from.getY(), to.getY());
        int maxY = Math.max(from.getY(), to.getY());
        int minZ = Math.min(from.getZ(), to.getZ());
        int maxZ = Math.max(from.getZ(), to.getZ());
        for (int x = minX; x <= maxX; x++) {
            for (int y = minY; y <= maxY; y++) {
                for (int z = minZ; z <= maxZ; z++) {
                    BlockPos pos = new BlockPos(x, y, z);
                    if (world.isAir(pos)) {
                        world.setBlockState(pos, state, 3);
                    }
                }
            }
        }
    }

    public static void hollow(WorldAccess world, BlockPos from, BlockPos to, BlockState state) {
        int minX = Math.min(from.getX(), to.getX());
        int maxX = Math.max(from.getX(), to.getX());
        int minY = Math.min(from.getY(), to.getY());
        int maxY = Math.max(from.getY(), to.getY());
        int minZ = Math.min(from.getZ(), to.getZ());
        int maxZ = Math.max(from.getZ(), to.getZ());
        for (int x = minX; x <= maxX; x++) {
            for (int y = minY; y <= maxY; y++) {
                for (int z = minZ; z <= maxZ; z++) {
                    boolean isEdge = x == minX || x == maxX
                        || y == minY || y == maxY
                        || z == minZ || z == maxZ;
                    if (isEdge) {
                        BlockPos pos = new BlockPos(x, y, z);
                        if (world.isAir(pos)) {
                            world.setBlockState(pos, state, 3);
                        }
                    }
                }
            }
        }
    }

    public static void pillar(WorldAccess world, BlockPos base, int height, BlockState state) {
        for (int y = 0; y < height; y++) {
            BlockPos pos = base.up(y);
            if (world.isAir(pos)) {
                world.setBlockState(pos, state, 3);
            }
        }
    }
}