package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.block.Blocks;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class OnsenStructure {
    public static void generate(WorldAccess world, BlockPos center) {
        int radius = 3;
        for (int dx = -radius; dx <= radius; dx++) {
            for (int dz = -radius; dz <= radius; dz++) {
                if (dx * dx + dz * dz <= radius * radius) {
                    BlockPos waterPos = center.add(dx, 0, dz);
                    if (world.isAir(waterPos)) {
                        world.setBlockState(waterPos, ModBlocks.ONSEN_WATER.getDefaultState(), 3);
                    }
                    if (dx * dx + dz * dz >= (radius - 1) * (radius - 1)) {
                        BlockPos borderPos = center.add(dx, 1, dz);
                        if (world.isAir(borderPos)) {
                            world.setBlockState(borderPos, Blocks.STONE.getDefaultState(), 3);
                        }
                    }
                }
            }
        }
        world.setBlockState(center.add(radius + 1, 1, 0), ModBlocks.STONE_LANTERN.getDefaultState(), 3);
        world.setBlockState(center.add(-radius - 1, 1, 0), ModBlocks.STONE_LANTERN.getDefaultState(), 3);
    }
}