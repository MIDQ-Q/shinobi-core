package com.example.shinobicore.item;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.itemgroup.v1.FabricItemGroup;
import net.minecraft.item.ArmorItem;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.item.ToolMaterials;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;

public class ModItems {
    public static final Item KATANA_IRON = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana_iron"), new KatanaItem(ToolMaterials.IRON, new Item.Settings().maxCount(1).maxDamage(0)));
    public static final Item KATANA_DIAMOND = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana_diamond"), new KatanaItem(ToolMaterials.DIAMOND, new Item.Settings().maxCount(1).maxDamage(0)));
    public static final Item KATANA_NETHERITE = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana_netherite"), new KatanaItem(ToolMaterials.NETHERITE, new Item.Settings().maxCount(1).maxDamage(0).fireproof()));
    public static final Item KATANA = KATANA_IRON; // Alias for backwards compatibility
    public static final Item FLAK_VEST = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "flak_vest"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.CHESTPLATE, new Item.Settings()));
    public static final Item NINJA_PANTS = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "ninja_pants"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.LEGGINGS, new Item.Settings()));
    public static final Item NINJA_SANDALS = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "ninja_sandals"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.BOOTS, new Item.Settings()));
    public static final Item NINJA_HOOD = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "ninja_hood"), new ArmorItem(ModArmorMaterials.NARUTO_FLAK, ArmorItem.Type.HELMET, new Item.Settings()));
    public static final Item SHURIKEN = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "shuriken"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 3f, 3.0f, 8));
    public static final Item KUNAI = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "kunai"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 5f, 2.2f, 12));
    public static final Item SCROLL = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "scroll"),
            new ScrollItem(new Item.Settings().maxCount(1)));

    public static void register() {
        Registry.register(Registries.ITEM_GROUP, new Identifier(ShinobiCore.MOD_ID, "main"),
                FabricItemGroup.builder()
                        .displayName(Text.translatable("itemGroup.shinobicore.main"))
                        .icon(() -> new ItemStack(KATANA_IRON))
                        .entries((context, entries) -> {
                            entries.add(KATANA_IRON);
                            entries.add(KATANA_DIAMOND);
                            entries.add(KATANA_NETHERITE);
                            entries.add(NINJA_HOOD);
                            entries.add(FLAK_VEST);
                            entries.add(NINJA_PANTS);
                            entries.add(NINJA_SANDALS);
                            entries.add(SHURIKEN);
                            entries.add(KUNAI);
                            entries.add(SCROLL);
                        })
                        .build());
        ShinobiCore.LOGGER.info("Registered katanas, armor, shuriken/kunai items + creative tab");
    }
}