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
 * Генерация рисовых полей (террасы с водой и молодым рисом).
 * Использует фарmland с водой для имитации рисовых чеков.
 */
public class RiceFieldFeature extends Feature<NoneFeatureConfiguration> {

    public RiceFieldFeature(Codec<NoneFeatureConfiguration> config) {
        super(config);
    }

    @Override
    public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context) {
        WorldGenLevel level = context.level();
        BlockPos origin = context.origin();
        RandomSource random = context.random();

        // Проверяем что это ровная земля
        BlockState ground = level.getBlockState(origin);
        if (!ground.is(Blocks.GRASS_BLOCK) && !ground.is(Blocks.DIRT)) {
            return false;
        }

        // Размер поля (прямоугольное 3x5 или 4x6)
        int width = 3 + random.nextInt(2); // 3-4
        int length = 5 + random.nextInt(2); // 5-6
        
        int fieldSize = 0;

        // Ориентация поля (север-юг или запад-восток)
        boolean horizontal = random.nextBoolean();

        for (int i = 0; i < width; i++) {
            for (int j = 0; j < length; j++) {
                int x = horizontal ? i : j;
                int z = horizontal ? j : i;
                
                // Центрируем поле вокруг origin
                int offsetX = x - width / 2;
                int offsetZ = z - length / 2;
                
                BlockPos pos = origin.offset(offsetX, 0, offsetZ);
                
                // Проверяем что блок подходит
                BlockState blockAt = level.getBlockState(pos);
                if (blockAt.is(Blocks.GRASS_BLOCK) || blockAt.is(Blocks.DIRT)) {
                    // Создаем террасу с водой
                    // Сначала копаем углубление
                    level.setBlock(pos, Blocks.FARMLAND.defaultBlockState(), 2);
                    
                    // Добавляем воду рядом для орошения (каждые 4 блока источник воды)
                    if ((i + j) % 4 == 0) {
                        BlockPos waterPos = pos.offset(1, 0, 0);
                        if (level.getBlockState(waterPos).is(Blocks.GRASS_BLOCK) || 
                            level.getBlockState(waterPos).is(Blocks.DIRT)) {
                            level.setBlock(waterPos.below(), Blocks.WATER.defaultBlockState(), 2);
                        }
                    }
                    
                    // Сажаем рис (пшеницу как заменитель, т.к. риса в ваниле нет)
                    // Шанс 70% что будет расти рис
                    if (random.nextFloat() < 0.7f) {
                        int growthStage = random.nextInt(4); // 0-3 стадия роста
                        BlockPos cropPos = pos.above();
                        if (level.isEmptyBlock(cropPos)) {
                            level.setBlock(cropPos, Blocks.WHEAT.defaultBlockState().setValue(
                                Blocks.WHEAT.getAgeProperty(), growthStage), 2);
                        }
                    }
                    
                    fieldSize++;
                }
            }
        }

        // Добавляем деревянный забор вокруг поля
        createFenceBorder(level, origin, width, length, horizontal, random);

        return fieldSize > 0;
    }

    private void createFenceBorder(WorldGenLevel level, BlockPos origin, int width, int length, 
                                   boolean horizontal, RandomSource random) {
        for (int i = -1; i <= width; i++) {
            for (int j = -1; j <= length; j++) {
                // Только края
                if (i != -1 && i != width && j != -1 && j != length) continue;
                
                int x = horizontal ? i : j;
                int z = horizontal ? j : i;
                
                int offsetX = x - width / 2;
                int offsetZ = z - length / 2;
                
                BlockPos fencePos = origin.offset(offsetX, 0, offsetZ);
                
                // Не ставим забор где уже есть блоки (кроме земли)
                BlockState blockAt = level.getBlockState(fencePos);
                if (blockAt.is(Blocks.GRASS_BLOCK) || blockAt.is(Blocks.DIRT) || blockAt.is(Blocks.FARMLAND)) {
                    // Шанс 80% что будет забор, иногда оставляем проходы
                    if (random.nextFloat() < 0.8f) {
                        level.setBlock(fencePos, Blocks.OAK_FENCE.defaultBlockState(), 2);
                    }
                }
            }
        }
    }
}