package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class HouseStructure {
    public static void generate(WorldAccess world, BlockPos center) {
        int w = 7, d = 5, h = 4;
        BlockPos floor = center.add(-w/2, 0, -d/2);
        BlockPos ceil = center.add(w/2, h, d/2);
        StructureBuilder.fill(world, floor, center.add(w/2, 0, d/2), ModBlocks.WOOD_PANEL.getDefaultState());
        StructureBuilder.hollow(world, floor.up(), ceil, ModBlocks.WOOD_PANEL.getDefaultState());
        world.setBlockState(center.add(0, 1, -d/2), ModBlocks.SHOJI.getDefaultState(), 3);
        world.setBlockState(center.add(0, 1, d/2), ModBlocks.SHOJI.getDefaultState(), 3);
        StructureBuilder.fill(world, ceil, center.add(w/2, h, d/2), ModBlocks.BEAM.getDefaultState());
        world.setBlockState(center.add(-2, 2, -1), ModBlocks.LANTERN.getDefaultState(), 3);
    }
}