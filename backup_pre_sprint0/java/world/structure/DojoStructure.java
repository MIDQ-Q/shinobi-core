package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class DojoStructure {
    public static void generate(WorldAccess world, BlockPos center) {
        int w = 9, d = 7, h = 5;
        BlockPos floor = center.add(-w/2, 0, -d/2);
        BlockPos ceil = center.add(w/2, h, d/2);
        StructureBuilder.fill(world, floor, center.add(w/2, 0, d/2), ModBlocks.TATAMI.getDefaultState());
        StructureBuilder.hollow(world, floor.up(), ceil, ModBlocks.WOOD_PANEL.getDefaultState());
        StructureBuilder.pillar(world, floor.up(), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(w/2, 1, -d/2), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(-w/2, 1, d/2), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(w/2, 1, d/2), h - 1, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.fill(world, ceil, center.add(w/2, h, d/2), ModBlocks.BEAM.getDefaultState());
        world.setBlockState(center.add(-2, 1, 0), ModBlocks.TRAINING_POST.getDefaultState(), 3);
        world.setBlockState(center.add(2, 1, 0), ModBlocks.TRAINING_POST.getDefaultState(), 3);
        world.setBlockState(center.add(-3, 2, -2), ModBlocks.LANTERN.getDefaultState(), 3);
        world.setBlockState(center.add(3, 2, 2), ModBlocks.LANTERN.getDefaultState(), 3);
    }
}