package com.example.shinobicore.world.structures;

import com.example.shinobicore.block.ModBlocks;
import com.example.shinobicore.world.structure.StructureBuilder;
import com.mojang.serialization.Codec;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.IWorld;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.NoneFeatureConfig;

import java.util.Random;

/**
 * Структура доджо клана
 */
public class ClanDojoStructure extends Feature<NoneFeatureConfig> {

    public ClanDojoStructure() {
        super(NoneFeatureConfig.CODEC);
    }

    @Override
    public boolean generate(IWorld world, Random rand, BlockPos pos) {
        if (!world.isAirBlock(pos)) return false;

        int width = 12;
        int depth = 10;
        int height = 5;

        // Пол из татами
        BlockPos floorStart = pos.add(-width/2, -1, -depth/2);
        BlockPos floorEnd = pos.add(width/2, -1, depth/2);
        StructureBuilder.fill(world, floorStart, floorEnd, net.minecraft.block.Blocks.WHITE_WOOL.getDefaultState());

        // Стены
        BlockPos wallStart = pos.add(-width/2, 0, -depth/2);
        BlockPos wallEnd = pos.add(width/2, height, depth/2);
        StructureBuilder.hollow(world, wallStart, wallEnd, ModBlocks.WOOD_PANEL.getDefaultState());

        // Крыша
        for (int x = -width/2 - 1; x <= width/2 + 1; x++) {
            for (int z = -depth/2 - 1; z <= depth/2 + 1; z++) {
                BlockPos roofPos = pos.add(x, height + 1, z);
                if (world.isAirBlock(roofPos)) {
                    world.setBlockState(roofPos, ModBlocks.BEAM.getDefaultState(), 3);
                }
            }
        }

        // Вход с тории
        ToriiGateStructure.generate(world, pos.add(0, 0, -depth/2 - 3));

        // Манекены внутри
        int[][] dummyPositions = {
            {-4, -3}, {4, -3}, {-4, 3}, {4, 3}
        };

        for (int[] p : dummyPositions) {
            BlockPos dummyPos = pos.add(p[0], 0, p[1]);
            StructureBuilder.pillar(world, dummyPos, 2, ModBlocks.BEAM.getDefaultState());
            world.setBlockState(dummyPos.up(2), ModBlocks.WOOD_PANEL.getDefaultState(), 3);
        }

        // Свитки на стенах
        world.setBlockState(pos.add(-width/2 + 1, 2, -depth/2 + 2), ModBlocks.SHOJI.getDefaultState(), 3);
        world.setBlockState(pos.add(width/2 - 1, 2, -depth/2 + 2), ModBlocks.SHOJI.getDefaultState(), 3);

        // Фонари по углам
        world.setBlockState(pos.add(-width/2 + 1, 1, -depth/2 + 1), ModBlocks.LANTERN.getDefaultState(), 3);
        world.setBlockState(pos.add(width/2 - 1, 1, -depth/2 + 1), ModBlocks.LANTERN.getDefaultState(), 3);
        world.setBlockState(pos.add(-width/2 + 1, 1, depth/2 - 1), ModBlocks.LANTERN.getDefaultState(), 3);
        world.setBlockState(pos.add(width/2 - 1, 1, depth/2 - 1), ModBlocks.LANTERN.getDefaultState(), 3);

        return true;
    }
}
