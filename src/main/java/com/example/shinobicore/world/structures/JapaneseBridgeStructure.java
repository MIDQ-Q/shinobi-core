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
 * Структура японского моста
 */
public class JapaneseBridgeStructure extends Feature<NoneFeatureConfig> {

    public JapaneseBridgeStructure() {
        super(NoneFeatureConfig.CODEC);
    }

    @Override
    public boolean generate(IWorld world, Random rand, BlockPos pos) {
        // Проверяем наличие воды рядом
        boolean hasWater = false;
        for (int x = -5; x <= 5; x++) {
            for (int z = -5; z <= 5; z++) {
                if (world.getBlockState(pos.add(x, -1, z)).getBlock().isIn(net.minecraft.tags.FluidTags.WATER)) {
                    hasWater = true;
                    break;
                }
            }
            if (hasWater) break;
        }

        if (!hasWater) return false;

        int length = 8;
        int width = 3;

        // Арочный мост
        for (int i = 0; i < length; i++) {
            int heightOffset = (int)(Math.sin((i / (float)length) * Math.PI) * 2);
            
            for (int w = -width/2; w <= width/2; w++) {
                BlockPos bridgePos = pos.add(i - length/2, heightOffset, w);
                
                // Перила
                if (w == -width/2 || w == width/2) {
                    if (world.isAirBlock(bridgePos.up(1))) {
                        world.setBlockState(bridgePos.up(1), ModBlocks.BEAM.getDefaultState(), 3);
                    }
                }
                
                // Пол моста
                if (world.isAirBlock(bridgePos)) {
                    world.setBlockState(bridgePos, ModBlocks.WOOD_PANEL.getDefaultState(), 3);
                }
                
                // Опоры под мостом
                if (heightOffset == 0 && (i == 0 || i == length - 1)) {
                    StructureBuilder.pillar(world, bridgePos.down(1), 3, ModBlocks.BEAM.getDefaultState());
                }
            }
        }

        return true;
    }
}
