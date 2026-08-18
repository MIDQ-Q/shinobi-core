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
 * Структура ворот Тории
 */
public class ToriiGateStructure extends Feature<NoneFeatureConfig> {

    public ToriiGateStructure() {
        super(NoneFeatureConfig.CODEC);
    }

    @Override
    public boolean generate(IWorld world, Random rand, BlockPos pos) {
        if (!world.isAirBlock(pos)) return false;

        // Два столба
        StructureBuilder.pillar(world, pos.add(-2, 0, 0), 5, ModBlocks.BEAM.getDefaultState());
        StructureBuilder.pillar(world, pos.add(2, 0, 0), 5, ModBlocks.BEAM.getDefaultState());

        // Верхняя перекладина (касуги)
        for (int x = -3; x <= 3; x++) {
            BlockPos beamPos = pos.add(x, 5, 0);
            if (world.isAirBlock(beamPos)) {
                world.setBlockState(beamPos, ModBlocks.BEAM.getDefaultState(), 3);
            }
        }

        // Нижняя перекладина (нуги)
        for (int x = -2; x <= 2; x++) {
            BlockPos beamPos = pos.add(x, 4, 0);
            if (world.isAirBlock(beamPos)) {
                world.setBlockState(beamPos, ModBlocks.BEAM.getDefaultState(), 3);
            }
        }

        return true;
    }
}
