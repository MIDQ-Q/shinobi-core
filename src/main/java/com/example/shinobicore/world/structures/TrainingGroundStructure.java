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
 * Структура тренировочного полигона шиноби
 */
public class TrainingGroundStructure extends Feature<NoneFeatureConfig> {

    public TrainingGroundStructure() {
        super(NoneFeatureConfig.CODEC);
    }

    @Override
    public boolean generate(IWorld world, Random rand, BlockPos pos) {
        if (!world.isAirBlock(pos)) return false;

        int size = 12;

        // Земляная площадка
        BlockPos groundStart = pos.add(-size/2, -1, -size/2);
        BlockPos groundEnd = pos.add(size/2, -1, size/2);
        StructureBuilder.fill(world, groundStart, groundEnd, net.minecraft.block.Blocks.GRASS_BLOCK.getDefaultState());

        // Манекены для тренировки (4 угла)
        int[][] positions = {
            {-4, -4}, {4, -4}, {-4, 4}, {4, 4}
        };

        for (int[] p : positions) {
            BlockPos dummyPos = pos.add(p[0], 0, p[1]);
            
            // Столб манекена
            StructureBuilder.pillar(world, dummyPos, 3, ModBlocks.BEAM.getDefaultState());
            
            // "Голова" манекена
            world.setBlockState(dummyPos.up(3), ModBlocks.WOOD_PANEL.getDefaultState(), 3);
            
            // Фонарь рядом
            world.setBlockState(dummyPos.add(1, 0, 1), ModBlocks.LANTERN.getDefaultState(), 3);
        }

        // Мишени в центре
        for (int i = -2; i <= 2; i += 2) {
            BlockPos targetPos = pos.add(i, 0, 0);
            world.setBlockState(targetPos.up(1), ModBlocks.SHOJI.getDefaultState(), 3);
            world.setBlockState(targetPos.up(2), ModBlocks.SHOJI.getDefaultState(), 3);
        }

        // Ворота на входе
        ToriiGateStructure.generate(world, pos.add(0, 0, -size/2 - 2));

        return true;
    }
}
