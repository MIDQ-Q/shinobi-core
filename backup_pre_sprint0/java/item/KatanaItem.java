package com.example.shinobicore.item;

import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterial;

/**
 * S2-07: Katana weapon without durability.
 * Balance is handled through stats and cooldowns, not item breaking.
 */
public class KatanaItem extends SwordItem {
    public KatanaItem(ToolMaterial material, Item.Settings settings) {
        super(material, 4, -2.4f, settings);
    }

    @Override
    public boolean isDamageable() {
        return false;
    }

    @Override
    public boolean isEnchantable(ItemStack stack) {
        return true;
    }

    @Override
    public int getEnchantability() {
        return this.getMaterial().getEnchantability();
    }

    @Override
    public boolean canRepair(ItemStack stack, ItemStack ingredient) {
        return false;
    }

    @Override
    public boolean isUsedOnRelease(ItemStack stack) {
        return false;
    }
}