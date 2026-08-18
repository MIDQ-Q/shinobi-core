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
 * Генерация прудов с карпами кои (использует обычную воду и лилии).
 * Создает небольшие декоративные пруды с кувшинками.
 */
public class KoiPondFeature extends Feature<NoneFeatureConfiguration> {

    public KoiPondFeature(Codec<NoneFeatureConfiguration> config) {
        super(config);
    }

    @Override
    public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context) {
        WorldGenLevel level = context.level();
        BlockPos origin = context.origin();
        RandomSource random = context.random();

        // Проверяем что это земля
        BlockState ground = level.getBlockState(origin);
        if (!ground.is(Blocks.GRASS_BLOCK) && !ground.is(Blocks.DIRT)) {
            return false;
        }

        // Размер пруда (радиус 2-3 блока)
        int radius = 2 + random.nextInt(2);
        int pondSize = 0;

        // Копаем котлован
        for (int x = -radius; x <= radius; x++) {
            for (int z = -radius; z <= radius; z++) {
                double dist = Math.sqrt(x * x + z * z);
                if (dist <= radius) {
                    BlockPos pos = origin.offset(x, 0, z);
                    
                    // Глубина пруда (1-2 блока)
                    int depth = 1 + (random.nextInt(3) == 0 ? 1 : 0); // 20% шанс глубины 2
                    
                    for (int d = 0; d < depth; d++) {
                        BlockPos digPos = pos.below(d);
                        BlockState blockAt = level.getBlockState(digPos);
                        
                        // Заменяем землю на воду
                        if (blockAt.is(Blocks.GRASS_BLOCK) || blockAt.is(Blocks.DIRT) || 
                            blockAt.is(Blocks.STONE) || blockAt.is(Blocks.SAND)) {
                            level.setBlock(digPos, Blocks.WATER.defaultBlockState(), 2);
                            pondSize++;
                        }
                    }
                    
                    // Добавляем кувшинки на поверхность воды
                    if (dist <= radius - 0.5 && random.nextFloat() < 0.3f) { // 30% шанс кувшинки
                        BlockPos surfacePos = pos.above();
                        if (level.getBlockState(surfacePos).is(Blocks.AIR) &&
                            level.getBlockState(surfacePos.below()).is(Blocks.WATER)) {
                            level.setBlock(surfacePos, Blocks.LILY_PAD.defaultBlockState(), 2);
                        }
                    }
                }
            }
        }

        // Добавляем немного гравия/песка на дно для красоты
        for (int attempts = 0; attempts < 5; attempts++) {
            int x = random.nextInt(radius * 2 + 1) - radius;
            int z = random.nextInt(radius * 2 + 1) - radius;
            if (x * x + z * z <= radius * radius) {
                BlockPos bottomPos = origin.offset(x, -1, z);
                if (level.getBlockState(bottomPos).is(Blocks.WATER)) {
                    // Ищем дно
                    while (!level.getBlockState(bottomPos.below()).isSolid() && bottomPos.getY() > origin.getY() - 3) {
                        bottomPos = bottomPos.below();
                    }
                    if (random.nextBoolean()) {
                        level.setBlock(bottomPos, Blocks.GRAVEL.defaultBlockState(), 2);
                    } else {
                        level.setBlock(bottomPos, Blocks.SAND.defaultBlockState(), 2);
                    }
                }
            }
        }

        return pondSize > 0;
    }
}