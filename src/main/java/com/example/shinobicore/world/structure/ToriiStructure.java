package com.example.shinobicore.world.structure;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.WorldAccess;

public class ToriiStructure {
    public static void generate(WorldAccess world, BlockPos center) {
        StructureBuilder.pillar(world, center.add(-2, 0, 0), 5, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, center.add(2, 0, 0), 5, ModBlocks.BEAM.getDefaultState());
        for (int x = -3; x <= 3; x++) {
            BlockPos pos = center.add(x, 5, 0);
            if (world.isAir(pos)) {
                world.setBlockState(pos, ModBlocks.BEAM.getDefaultState(), 3);
            }
        }
        for (int x = -2; x <= 2; x++) {
            BlockPos pos = center.add(x, 4, 0);
            if (world.isAir(pos)) {
                world.setBlockState(pos, ModBlocks.BEAM.getDefaultState(), 3);
            }
        }
    }
}