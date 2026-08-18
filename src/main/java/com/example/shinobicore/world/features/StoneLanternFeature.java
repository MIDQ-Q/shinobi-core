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
 * Генерация каменных фонарей.
 * Размещает декоративные каменные фонари вдоль дорог, у домов и в садах.
 */
public class StoneLanternFeature extends Feature<NoneFeatureConfiguration> {

    public StoneLanternFeature(Codec<NoneFeatureConfiguration> config) {
        super(config);
    }

    @Override
    public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context) {
        WorldGenLevel level = context.level();
        BlockPos origin = context.origin();
        RandomSource random = context.random();

        // Проверяем что место пустое и под ним твердый блок
        if (!level.isEmptyBlock(origin)) {
            return false;
        }

        BlockState ground = level.getBlockState(origin.below());
        if (!ground.isSolid()) {
            return false;
        }

        // Конструкция фонаря (3 блока высотой)
        // Основание
        level.setBlock(origin.below(), Blocks.COBBLESTONE_WALL.defaultBlockState(), 2);
        
        // Столб
        level.setBlock(origin, Blocks.COBBLESTONE_WALL.defaultBlockState(), 2);
        
        // Крыша фонаря
        level.setBlock(origin.above(), Blocks.STONE_SLAB.defaultBlockState(), 2);
        
        // Источник света внутри (факел или красный факел для ночного освещения)
        // В майнкрафте нельзя поставить блок света внутрь стены, поэтому используем факел на стене
        // Или можно использовать sea pickle для подводных фонарей, но тут сухопутный вариант
        
        // Альтернативная конструкция с использованием блоков полностью:
        // Сносим предыдущие блоки и строим заново более правильно
        level.removeBlock(origin.below(), false);
        level.removeBlock(origin, false);
        level.removeBlock(origin.above(), false);
        
        // Полное основание
        level.setBlock(origin.below(2), Blocks.STONE_BRICK_SLAB.defaultBlockState(), 2);
        
        // Ножка
        level.setBlock(origin.below(), Blocks.COBBLESTONE_WALL.defaultBlockState(), 2);
        
        // Камера с огнем (используем блок забора как основу)
        level.setBlock(origin, Blocks.COBBLESTONE_WALL.defaultBlockState(), 2);
        
        // Крыша
        level.setBlock(origin.above(), Blocks.STONE_PRESSURE_PLATE.defaultBlockState(), 2);
        
        // Добавляем факел рядом для освещения (опционально, если нужно реальное освещение)
        // level.setBlock(origin.east().above(), Blocks.TORCH.defaultBlockState(), 2);

        return true;
    }
}