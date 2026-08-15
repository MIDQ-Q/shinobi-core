package com.example.shinobicore.item;

import net.minecraft.item.Item;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterial;

public class KatanaItem extends SwordItem {
    public KatanaItem(ToolMaterial material, Item.Settings settings) {
        super(material, 4, -2.4f, settings);
    }
}