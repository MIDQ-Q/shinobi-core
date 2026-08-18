package com.example.shinobicore.world.structures;

import com.example.shinobicore.block.ModBlocks;
import com.example.shinobicore.world.structure.StructureBuilder;
import com.mojang.serialization.Codec;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.IWorld;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.IFeatureConfig;
import net.minecraft.world.gen.feature.NoneFeatureConfig;

import java.util.Random;

/**
 * Структура традиционного японского дома
 */
public class JapaneseHouseStructure extends Feature<NoneFeatureConfig> {

    public JapaneseHouseStructure() {
        super(NoneFeatureConfig.CODEC);
    }

    @Override
    public boolean generate(IWorld world, Random rand, BlockPos pos) {
        if (!world.isAirBlock(pos)) return false;

        int width = 7;
        int depth = 6;
        int height = 4;

        // Пол
        BlockPos floorStart = pos.add(-width/2, -1, -depth/2);
        BlockPos floorEnd = pos.add(width/2, -1, depth/2);
        StructureBuilder.fill(world, floorStart, floorEnd, ModBlocks.WOOD_PANEL.getDefaultState());

        // Стены
        BlockPos wallStart = pos.add(-width/2, 0, -depth/2);
        BlockPos wallEnd = pos.add(width/2, height, depth/2);
        StructureBuilder.hollow(world, wallStart, wallEnd, ModBlocks.WOOD_PANEL.getDefaultState());

        // Двери сёдзи
        world.setBlockState(pos.add(0, 1, -depth/2), ModBlocks.SHOJI.getDefaultState(), 3);
        world.setBlockState(pos.add(0, 1, depth/2), ModBlocks.SHOJI.getDefaultState(), 3);

        // Крыша (упрощённая)
        for (int x = -width/2 - 1; x <= width/2 + 1; x++) {
            for (int z = -depth/2 - 1; z <= depth/2 + 1; z++) {
                BlockPos roofPos = pos.add(x, height + 1, z);
                if (world.isAirBlock(roofPos)) {
                    world.setBlockState(roofPos, ModBlocks.BEAM.getDefaultState(), 3);
                }
            }
        }

        // Фонарь внутри
        world.setBlockState(pos.add(-2, 1, -1), ModBlocks.LANTERN.getDefaultState(), 3);

        return true;
    }
}
