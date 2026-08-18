package com.example.shinobicore.block.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.block.ModBlocks;
import net.minecraft.block.entity.BlockEntityType;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

public class ModBlockEntities {

    public static final BlockEntityType<TrainingPostBlockEntity> TRAINING_POST =
        Registry.register(Registries.BLOCK_ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "training_post"),
            BlockEntityType.Builder.create(TrainingPostBlockEntity::new, ModBlocks.TRAINING_POST).build(null));

    public static final BlockEntityType<OnsenBlockEntity> ONSEN =
        Registry.register(Registries.BLOCK_ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "onsen"),
            BlockEntityType.Builder.create(OnsenBlockEntity::new, ModBlocks.ONSEN_WATER).build(null));

    public static final BlockEntityType<ChakraAltarBlockEntity> CHAKRA_ALTAR =
        Registry.register(Registries.BLOCK_ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "chakra_altar"),
            BlockEntityType.Builder.create(ChakraAltarBlockEntity::new, ModBlocks.CHAKRA_ALTAR).build(null));

    public static void register() {
        ShinobiCore.LOGGER.info("[S7] Registered block entities");
    }
}