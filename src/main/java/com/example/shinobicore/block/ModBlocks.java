package com.example.shinobicore.block;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.block.entity.ChakraAltarBlockEntity;
import com.example.shinobicore.block.entity.OnsenBlockEntity;
import com.example.shinobicore.block.entity.TrainingPostBlockEntity;
import net.fabricmc.fabric.api.object.builder.v1.block.FabricBlockSettings;
import net.minecraft.block.Block;
import net.minecraft.block.PillarBlock;
import net.minecraft.block.Blocks;
import net.minecraft.item.BlockItem;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.sound.BlockSoundGroup;
import net.minecraft.util.Identifier;

/**
 * S7-01/S7-02: All custom blocks for Japanese architecture and decor.
 */
public class ModBlocks {

    // === S7-01: Japanese building blocks ===
    public static final Block TATAMI = register("tatami",
        new Block(FabricBlockSettings.copyOf(Blocks.HAY_BLOCK).sounds(BlockSoundGroup.GRASS)));

    public static final Block SHOJI = register("shoji",
        new Block(FabricBlockSettings.copyOf(Blocks.WHITE_WOOL).sounds(BlockSoundGroup.WOOD).nonOpaque()));

    public static final Block WOOD_PANEL = register("wood_panel",
        new Block(FabricBlockSettings.copyOf(Blocks.OAK_PLANKS)));

    public static final Block BEAM = register("beam",
        new PillarBlock(FabricBlockSettings.copyOf(Blocks.OAK_LOG)));

    public static final Block LANTERN = register("lantern",
        new Block(FabricBlockSettings.copyOf(Blocks.LANTERN).luminance(state -> 14)));

    public static final Block STONE_PATH = register("stone_path",
        new Block(FabricBlockSettings.copyOf(Blocks.STONE_BRICKS)));

    // === S7-02: Decorative blocks ===
    public static final Block SAKURA_LEAVES = register("sakura_leaves",
        new Block(FabricBlockSettings.copyOf(Blocks.OAK_LEAVES)));

    public static final Block SAKURA_LOG = register("sakura_log",
        new PillarBlock(FabricBlockSettings.copyOf(Blocks.OAK_LOG)));

    public static final Block STONE_LANTERN = register("stone_lantern",
        new Block(FabricBlockSettings.copyOf(Blocks.STONE).luminance(state -> 10)));

    // === S7-03: Training post ===
    public static final Block TRAINING_POST = register("training_post",
        new TrainingPostBlock(FabricBlockSettings.copyOf(Blocks.OAK_LOG).sounds(BlockSoundGroup.WOOD)));

    // === S7-04: Onsen water ===
    public static final Block ONSEN_WATER = register("onsen_water",
        new OnsenBlock(FabricBlockSettings.copyOf(Blocks.WATER).sounds(BlockSoundGroup.GLASS)));

    // === S7-05: Chakra altar ===
    public static final Block CHAKRA_ALTAR = register("chakra_altar",
        new ChakraAltarBlock(FabricBlockSettings.copyOf(Blocks.STONE).luminance(state -> 8)));

    // === Registration ===
    private static Block register(String name, Block block) {
        return Registry.register(Registries.BLOCK, new Identifier(ShinobiCore.MOD_ID, name), block);
    }

    private static Item registerBlockItem(String name, Block block) {
        return Registry.register(Registries.ITEM, new Identifier(ShinobiCore.MOD_ID, name),
            new BlockItem(block, new Item.Settings()));
    }

    public static void register() {
        registerBlockItem("tatami", TATAMI);
        registerBlockItem("shoji", SHOJI);
        registerBlockItem("wood_panel", WOOD_PANEL);
        registerBlockItem("beam", BEAM);
        registerBlockItem("lantern", LANTERN);
        registerBlockItem("stone_path", STONE_PATH);
        registerBlockItem("sakura_leaves", SAKURA_LEAVES);
        registerBlockItem("sakura_log", SAKURA_LOG);
        registerBlockItem("stone_lantern", STONE_LANTERN);
        registerBlockItem("training_post", TRAINING_POST);
        registerBlockItem("onsen_water", ONSEN_WATER);
        registerBlockItem("chakra_altar", CHAKRA_ALTAR);
        ShinobiCore.LOGGER.info("[S7] Registered {} blocks", 12);
    }
}