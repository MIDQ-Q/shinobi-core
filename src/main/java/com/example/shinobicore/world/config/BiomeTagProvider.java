package com.example.shinobicore.world.config;

import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.tags.TagKey;
import net.minecraft.world.level.biome.Biome;

/**
 * Класс с тегами биомов для генерации мира.
 * Определяет группы биомов для размещения японских структур и растений.
 */
public class BiomeTagProvider {
    
    // Лесные биомы (для сакур и бамбука)
    public static final TagKey<Biome> FOREST_BIOMES = TagKey.create(Registries.BIOME, 
        new ResourceLocation("forge", "is_forest"));
    
    // Равнины (для рисовых полей)
    public static final TagKey<Biome> PLAINS_BIOMES = TagKey.create(Registries.BIOME, 
        new ResourceLocation("minecraft", "plains"));
    
    // Биомы у воды (для прудов с кои)
    public static final TagKey<Biome> WATER_ADJACENT_BIOMES = TagKey.create(Registries.BIOME, 
        new ResourceLocation("forge", "is_water"));
    
    // Все биомы (для фонарей, домов, тренировочных полигонов)
    public static final TagKey<Biome> ALL_BIOMES = TagKey.create(Registries.BIOME, 
        new ResourceLocation("minecraft", "overworld"));
    
    // Горные биомы (для огромных японских гор)
    public static final TagKey<Biome> MOUNTAIN_BIOMES = TagKey.create(Registries.BIOME, 
        new ResourceLocation("forge", "is_mountain"));
}