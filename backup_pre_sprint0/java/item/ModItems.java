package com.example.shinobicore.item;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.item.Item;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterials;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

/**
 * Item registry. Katana = EF weapon candidate (HLD 4.2).
 * Until EF jar is present, katana works as a vanilla sword item.
 */
public final class ModItems {

    public static final Item KATANA = Registry.register(
        Registries.ITEM,
        new Identifier(ShinobiCore.MOD_ID, "katana"),
        new SwordItem(ToolMaterials.IRON, 3, -2.4f, new Item.Settings())
    );

    private ModItems() {}

    public static void init() {
        ShinobiCore.LOGGER.info("ModItems registered");
    }
}