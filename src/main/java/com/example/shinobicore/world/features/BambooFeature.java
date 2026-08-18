package com.example.shinobicore.world.features;

import com.mojang.serialization.Codec;
import net.minecraft.core.BlockPos;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.FeaturePlaceContext;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;

/**
 * Генерация бамбуковых рощ.
 * Создает кластеры высокого бамбука на подходящей земле (трава, подзол).
 */
public class BambooFeature extends Feature<NoneFeatureConfiguration> {

    public BambooFeature(Codec<NoneFeatureConfiguration> config) {
        super(config);
    }

    @Override
    public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context) {
        WorldGenLevel level = context.level();
        BlockPos origin = context.origin();
        RandomSource random = context.random();

        if (!level.isEmptyBlock(origin)) {
            return false;
        }

        BlockState ground = level.getBlockState(origin.below());
        if (!ground.is(Blocks.GRASS_BLOCK) && !ground.is(Blocks.DIRT) && !ground.is(Blocks.PODZOL) && !ground.is(Blocks.COARSE_DIRT)) {
            return false;
        }

        // Определяем размер рощи (радиус)
        int radius = 2 + random.nextInt(3); // 2-4 блока
        int clusterSize = 0;

        for (int x = -radius; x <= radius; x++) {
            for (int z = -radius; z <= radius; z++) {
                if (x * x + z * z <= radius * radius) {
                    BlockPos pos = origin.offset(x, 0, z);
                    
                    // Шанс роста бамбука в ячейке (не сплошняком, а с пробелами)
                    if (random.nextFloat() < 0.7f) {
                        BlockState groundAtPos = level.getBlockState(pos.below());
                        if (groundAtPos.is(Blocks.GRASS_BLOCK) || groundAtPos.is(Blocks.DIRT) || groundAtPos.is(Blocks.PODZOL)) {
                            if (level.isEmptyBlock(pos) && level.isEmptyBlock(pos.above())) {
                                // Высота бамбука
                                int height = 4 + random.nextInt(8); // 4-11 блоков
                                
                                for (int y = 0; y < height; y++) {
                                    BlockPos bambooPos = pos.above(y);
                                    // Бамбук растет только если под ним бамбук или земля
                                    if (y == 0 || level.getBlockState(bambooPos.below()).is(Blocks.BAMBOO)) {
                                        level.setBlock(bambooPos, Blocks.BAMBOO.defaultBlockState(), 2);
                                        // Иногда добавляем листья (на самом деле бамбук в майнкрафте сам по себе блок, 
                                        // но можно добавить листву вокруг для красоты, если нужно)
                                    }
                                }
                                clusterSize++;
                            }
                        }
                    }
                }
            }
        }

        return clusterSize > 0;
    }
}