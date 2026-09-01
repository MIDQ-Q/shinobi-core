package com.example.shinobicore.item;
import net.minecraft.item.Item;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterials;
public class KatanaItem extends SwordItem {
    public KatanaItem() {
        super(ToolMaterials.IRON, 4, -2.0f, new Item.Settings().maxCount(1));
    }
}