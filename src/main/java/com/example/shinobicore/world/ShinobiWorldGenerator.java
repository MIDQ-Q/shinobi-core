package com.example.shinobicore.world;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.world.config.WorldGenConfig;
import com.example.shinobicore.world.features.*;
import com.example.shinobicore.world.structures.*;
import net.minecraft.core.registries.Registries;
import net.minecraft.data.worldgen.BootstapContext;
import net.minecraft.data.worldgen.PlacementUtils;
import net.minecraft.data.worldgen.placement.PlacementUtils;
import net.minecraft.data.worldgen.placement.VegetationPlacements;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.biome.Biome;
import net.minecraft.world.level.biome.Biomes;
import net.minecraft.world.level.levelgen.GenerationStep;
import net.minecraft.world.level.levelgen.placement.PlacedFeature;
import net.minecraft.world.level.levelgen.placement.RarityFilter;
import net.minecraft.world.level.levelgen.structure.Structure;
import net.minecraftforge.common.world.BiomeModifier;
import net.minecraftforge.common.world.ForgeBiomeModifiers;
import net.minecraftforge.event.lifecycle.RegisterDataFiltersEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Основной генератор мира в стиле средневековой Японии
 * Реализует гибридный подход: модификация биомов + кастомные структуры
 */
public class ShinobiWorldGenerator {
    
    public static final String MOD_ID = ShibuCore.MOD_ID;
    
    // Registry для фич (Features)
    public static final DeferredRegister<net.minecraft.world.level.levelgen.feature.Feature<?>> FEATURES = 
        DeferredRegister.create(ForgeRegistries.FEATURES, MOD_ID);
    
    // Registry для структур (Structures)
    public static final DeferredRegister<Structure> STRUCTURES = 
        DeferredRegister.create(Registries.STRUCTURE, MOD_ID);
    
    // Registry для размещений (Placed Features)
    public static final DeferredRegister<PlacedFeature> PLACED_FEATURES = 
        DeferredRegister.create(Registries.PLACED_FEATURE, MOD_ID);
    
    // Registry для модификаторов биомов
    public static final DeferredRegister<BiomeModifier> BIOME_MODIFIERS = 
        DeferredRegister.create(ForgeRegistries.Keys.BIOME_MODIFIERS, MOD_ID);
    
    // === FEATURES ===
    
    // Деревья
    public static final RegistryObject<SakuraTreeFeature> SAKURA_TREE = FEATURES.register("sakura_tree", 
        () -> new SakuraTreeFeature(null));
    public static final RegistryObject<BambooFeature> BAMBOO = FEATURES.register("bamboo", 
        () -> new BambooFeature(com.mojang.serialization.Codec.unit(com.example.shinobicore.world.features.BambooFeature::new)));
    
    // Декорации
    public static final RegistryObject<StoneLanternFeature> STONE_LANTERN = FEATURES.register("stone_lantern", 
        () -> new StoneLanternFeature());
    public static final RegistryObject<KoiPondFeature> KOI_POND = FEATURES.register("koi_pond", 
        () -> new KoiPondFeature());
    public static final RegistryObject<RiceFieldFeature> RICE_FIELD = FEATURES.register("rice_field", 
        () -> new RiceFieldFeature());
    public static final RegistryObject<ZenGardenFeature> ZEN_GARDEN = FEATURES.register("zen_garden", 
        () -> new ZenGardenFeature());
    
    // Структуры
    public static final RegistryObject<JapaneseHouseStructure> JAPANESE_HOUSE = FEATURES.register("japanese_house", 
        () -> new JapaneseHouseStructure());
    public static final RegistryObject<ToriiGateStructure> TORII_GATE = FEATURES.register("torii_gate", 
        () -> new ToriiGateStructure());
    public static final RegistryObject<JapaneseBridgeStructure> JAPANESE_BRIDGE = FEATURES.register("japanese_bridge", 
        () -> new JapaneseBridgeStructure());
    public static final RegistryObject<HiddenVillageStructure> HIDDEN_VILLAGE = FEATURES.register("hidden_village", 
        () -> new HiddenVillageStructure());
    public static final RegistryObject<TrainingGroundStructure> TRAINING_GROUND = FEATURES.register("training_ground", 
        () -> new TrainingGroundStructure());
    public static final RegistryObject<ClanDojoStructure> CLAN_DOJO = FEATURES.register("clan_dojo", 
        () -> new ClanDojoStructure());
    
    // === PLACED FEATURES ===
    
    // Сакуры - часто в лесах
    public static final RegistryObject<PlacedFeature> SAKURA_TREE_PLACED = PLACED_FEATURES.register("sakura_tree_placed",
        () -> new PlacedFeature(SAKURA_TREE.get().defaultConfiguration(), 
            PlacementUtils.countExtra(3, 0.1f, 2)));
    
    // Бамбук - реже
    public static final RegistryObject<PlacedFeature> BAMBOO_PLACED = PLACED_FEATURES.register("bamboo_placed",
        () -> new PlacedFeature(BAMBOO.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(4)));
    
    // Фонари - вдоль дорог
    public static final RegistryObject<PlacedFeature> STONE_LANTERN_PLACED = PLACED_FEATURES.register("stone_lantern_placed",
        () -> new PlacedFeature(STONE_LANTERN.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(8)));
    
    // Пруды с кои - редко
    public static final RegistryObject<PlacedFeature> KOI_POND_PLACED = PLACED_FEATURES.register("koi_pond_placed",
        () -> new PlacedFeature(KOI_POND.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(12)));
    
    // Рисовые поля - средне
    public static final RegistryObject<PlacedFeature> RICE_FIELD_PLACED = PLACED_FEATURES.register("rice_field_placed",
        () -> new PlacedFeature(RICE_FIELD.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(6)));
    
    // Дзен сады - редко
    public static final RegistryObject<PlacedFeature> ZEN_GARDEN_PLACED = PLACED_FEATURES.register("zen_garden_placed",
        () -> new PlacedFeature(ZEN_GARDEN.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(10)));
    
    // Дома - средне
    public static final RegistryObject<PlacedFeature> JAPANESE_HOUSE_PLACED = PLACED_FEATURES.register("japanese_house_placed",
        () -> new PlacedFeature(JAPANESE_HOUSE.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(5)));
    
    // Ворота тории - редко (у храмов)
    public static final RegistryObject<PlacedFeature> TORII_GATE_PLACED = PLACED_FEATURES.register("torii_gate_placed",
        () -> new PlacedFeature(TORII_GATE.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(15)));
    
    // Мосты - над реками
    public static final RegistryObject<PlacedFeature> JAPANESE_BRIDGE_PLACED = PLACED_FEATURES.register("japanese_bridge_placed",
        () -> new PlacedFeature(JAPANESE_BRIDGE.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(8)));
    
    // Деревни шиноби - очень редко
    public static final RegistryObject<PlacedFeature> HIDDEN_VILLAGE_PLACED = PLACED_FEATURES.register("hidden_village_placed",
        () -> new PlacedFeature(HIDDEN_VILLAGE.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(40)));
    
    // Тренировочные полигоны - средне
    public static final RegistryObject<PlacedFeature> TRAINING_GROUND_PLACED = PLACED_FEATURES.register("training_ground_placed",
        () -> new PlacedFeature(TRAINING_GROUND.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(10)));
    
    // Доджо кланов - редко
    public static final RegistryObject<PlacedFeature> CLAN_DOJO_PLACED = PLACED_FEATURES.register("clan_dojo_placed",
        () -> new PlacedFeature(CLAN_DOJO.get().defaultConfiguration(), 
            RarityFilter.onAverageOnceEvery(20)));
    
    // === BIOME MODIFIERS ===
    
    // Модификатор для лесных биомов (добавляет сакуры и бамбук)
    public static final RegistryObject<BiomeModifier> ADD_SAKURA_TO_FORESTS = BIOME_MODIFIERS.register("add_sakura_to_forests",
        () -> new ForgeBiomeModifiers.AddFeaturesBiomeModifier(
            BiomeTagProvider.FOREST_BIOMES,
            ResourceKey.create(Registries.PLACED_FEATURE, new ResourceLocation(MOD_ID, "sakura_tree_placed")),
            GenerationStep.Decoration.VEGETAL_DECORATION
        ));
    
    public static final RegistryObject<BiomeModifier> ADD_BAMBOO_TO_FORESTS = BIOME_MODIFIERS.register("add_bamboo_to_forests",
        () -> new ForgeBiomeModifiers.AddFeaturesBiomeModifier(
            BiomeTagProvider.FOREST_BIOMES,
            ResourceKey.create(Registries.PLACED_FEATURE, new ResourceLocation(MOD_ID, "bamboo_placed")),
            GenerationStep.Decoration.VEGETAL_DECORATION
        ));
    
    // Модификатор для равнин (добавляет рисовые поля)
    public static final RegistryObject<BiomeModifier> ADD_RICE_FIELDS_TO_PLAINS = BIOME_MODIFIERS.register("add_rice_fields_to_plains",
        () -> new ForgeBiomeModifiers.AddFeaturesBiomeModifier(
            BiomeTagProvider.PLAINS_BIOMES,
            ResourceKey.create(Registries.PLACED_FEATURE, new ResourceLocation(MOD_ID, "rice_field_placed")),
            GenerationStep.Decoration.VEGETAL_DECORATION
        ));
    
    // Модификатор для всех биомов (добавляет фонари)
    public static final RegistryObject<BiomeModifier> ADD_STONE_LANTERNS = BIOME_MODIFIERS.register("add_stone_lanterns",
        () -> new ForgeBiomeModifiers.AddFeaturesBiomeModifier(
            BiomeTagProvider.ALL_BIOMES,
            ResourceKey.create(Registries.PLACED_FEATURE, new ResourceLocation(MOD_ID, "stone_lantern_placed")),
            GenerationStep.Decoration.VEGETAL_DECORATION
        ));
    
    // Модификатор для биомов у воды (добавляет пруды с кои)
    public static final RegistryObject<BiomeModifier> ADD_KOI_PONDS = BIOME_MODIFIERS.register("add_koi_ponds",
        () -> new ForgeBiomeModifiers.AddFeaturesBiomeModifier(
            BiomeTagProvider.WATER_ADJACENT_BIOMES,
            ResourceKey.create(Registries.PLACED_FEATURE, new ResourceLocation(MOD_ID, "koi_pond_placed")),
            GenerationStep.Decoration.VEGETAL_DECORATION
        ));
    
    // Модификатор для всех биомов (добавляет дома)
    public static final RegistryObject<BiomeModifier> ADD_JAPANESE_HOUSES = BIOME_MODIFIERS.register("add_japanese_houses",
        () -> new ForgeBiomeModifiers.AddFeaturesBiomeModifier(
            BiomeTagProvider.ALL_BIOMES,
            ResourceKey.create(Registries.PLACED_FEATURE, new ResourceLocation(MOD_ID, "japanese_house_placed")),
            GenerationStep.Decoration.SURFACE_STRUCTURES
        ));
    
    // Модификатор для всех биомов (добавляет тренировочные полигоны)
    public static final RegistryObject<BiomeModifier> ADD_TRAINING_GROUNDS = BIOME_MODIFIERS.register("add_training_grounds",
        () -> new ForgeBiomeModifiers.AddFeaturesBiomeModifier(
            BiomeTagProvider.ALL_BIOMES,
            ResourceKey.create(Registries.PLACED_FEATURE, new ResourceLocation(MOD_ID, "training_ground_placed")),
            GenerationStep.Decoration.SURFACE_STRUCTURES
        ));
    
    // Модификатор для редких структур (деревни, доджо)
    public static final RegistryObject<BiomeModifier> ADD_HIDDEN_VILLAGES = BIOME_MODIFIERS.register("add_hidden_villages",
        () -> new ForgeBiomeModifiers.AddFeaturesBiomeModifier(
            BiomeTagProvider.ALL_BIOMES,
            ResourceKey.create(Registries.PLACED_FEATURE, new ResourceLocation(MOD_ID, "hidden_village_placed")),
            GenerationStep.Decoration.SURFACE_STRUCTURES
        ));
    
    /**
     * Регистрация всех регистров
     */
    public static void register() {
        // Регистры уже зарегистрированы через DeferredRegister
        ShibuCore.LOGGER.info("Shinobi World Generator registered successfully!");
        ShibuCore.LOGGER.info("Features: {}", FEATURES.getEntries().size());
        ShibuCore.LOGGER.info("Structures: {}", STRUCTURES.getEntries().size());
        ShibuCore.LOGGER.info("Placed Features: {}", PLACED_FEATURES.getEntries().size());
        ShibuCore.LOGGER.info("Biome Modifiers: {}", BIOME_MODIFIERS.getEntries().size());
    }
}
