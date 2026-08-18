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
 * Генерация дзен-садов (каменные сады с гравием и узорами).
 * Создает небольшие площадки с гравием, мхом и декоративными камнями.
 */
public class ZenGardenFeature extends Feature<NoneFeatureConfiguration> {

    public ZenGardenFeature(Codec<NoneFeatureConfiguration> config) {
        super(config);
    }

    @Override
    public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context) {
        WorldGenLevel level = context.level();
        BlockPos origin = context.origin();
        RandomSource random = context.random();

        // Проверяем что это ровная земля
        BlockState ground = level.getBlockState(origin);
        if (!ground.is(Blocks.GRASS_BLOCK) && !ground.is(Blocks.DIRT) && !ground.is(Blocks.SAND)) {
            return false;
        }

        // Размер сада (квадрат 5x5 или 6x6)
        int size = 5 + random.nextInt(2);
        int gardenSize = 0;

        // Выравниваем площадку
        for (int x = 0; x < size; x++) {
            for (int z = 0; z < size; z++) {
                BlockPos pos = origin.offset(x - size / 2, 0, z - size / 2);
                
                // Заменяем верхний блок на гравий или песок (основа сада)
                BlockState blockAt = level.getBlockState(pos);
                if (blockAt.is(Blocks.GRASS_BLOCK) || blockAt.is(Blocks.DIRT) || 
                    blockAt.is(Blocks.STONE) || blockAt.is(Blocks.SAND)) {
                    
                    // Выбираем материал основы
                    BlockState baseBlock;
                    if (random.nextFloat() < 0.7f) {
                        baseBlock = Blocks.GRAVEL.defaultBlockState(); // Гравий для "воды"
                    } else if (random.nextFloat() < 0.5f) {
                        baseBlock = Blocks.SAND.defaultBlockState();
                    } else {
                        baseBlock = Blocks.COARSE_DIRT.defaultBlockState();
                    }
                    
                    level.setBlock(pos, baseBlock, 2);
                    gardenSize++;
                }
            }
        }

        // Добавляем декоративные камни (большие булыжники)
        int rockCount = 2 + random.nextInt(3); // 2-4 камня
        for (int i = 0; i < rockCount; i++) {
            int rx = random.nextInt(size);
            int rz = random.nextInt(size);
            BlockPos rockPos = origin.offset(rx - size / 2, 0, rz - size / 2);
            
            // Камень может быть высотой 1-2 блока
            int rockHeight = 1 + (random.nextInt(3) == 0 ? 1 : 0);
            
            for (int h = 0; h < rockHeight; h++) {
                BlockPos stonePos = rockPos.above(h);
                if (level.isEmptyBlock(stonePos) || level.getBlockState(stonePos).is(Blocks.GRAVEL)) {
                    level.setBlock(stonePos, Blocks.COBBLESTONE.defaultBlockState(), 2);
                }
            }
        }

        // Добавляем мох (подушки мха)
        int mossCount = 3 + random.nextInt(4);
        for (int i = 0; i < mossCount; i++) {
            int mx = random.nextInt(size);
            int mz = random.nextInt(size);
            BlockPos mossPos = origin.offset(mx - size / 2, 0, mz - size / 2);
            
            // Мох растет только на гравии/песке
            BlockState below = level.getBlockState(mossPos);
            if ((below.is(Blocks.GRAVEL) || below.is(Blocks.SAND)) && level.isEmptyBlock(mossPos.above())) {
                level.setBlock(mossPos.above(), Blocks.MOSS_CARPET.defaultBlockState(), 2);
            }
        }

        // Добавляем бамбук или кусты по краям (опционально)
        if (random.nextFloat() < 0.5f) {
            // Шанс 50% что будут растения по краям
            for (int side = 0; side < 4; side++) {
                if (random.nextBoolean()) {
                    int bx, bz;
                    switch (side) {
                        case 0: bx = 0; bz = size / 2; break; // Север
                        case 1: bx = size - 1; bz = size / 2; break; // Юг
                        case 2: bx = size / 2; bz = 0; break; // Запад
                        case 3: bx = size / 2; bz = size - 1; break; // Восток
                        default: bx = 0; bz = 0;
                    }
                    BlockPos plantPos = origin.offset(bx - size / 2, 0, bz - size / 2);
                    if (level.isEmptyBlock(plantPos.above())) {
                        // Сажаем азалию или куст
                        level.setBlock(plantPos.above(), Blocks.AZALEA.defaultBlockState(), 2);
                    }
                }
            }
        }

        return gardenSize > 0;
    }
}