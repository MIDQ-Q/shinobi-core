package com.example.shinobicore.item;

import net.minecraft.item.ArmorItem;
import net.minecraft.item.ArmorMaterial;
import net.minecraft.item.Items;
import net.minecraft.recipe.Ingredient;
import net.minecraft.sound.SoundEvent;
import net.minecraft.sound.SoundEvents;

public class ModArmorMaterials {
    public static final ArmorMaterial NARUTO_FLAK = new ArmorMaterial() {
        @Override public int getDurability(ArmorItem.Type type) { return switch(type) { case HELMET -> 165; case CHESTPLATE -> 240; case LEGGINGS -> 225; case BOOTS -> 195; }; }
        @Override public int getProtection(ArmorItem.Type type) { return switch(type) { case HELMET -> 2; case CHESTPLATE -> 6; case LEGGINGS -> 5; case BOOTS -> 2; }; }
        @Override public int getEnchantability() { return 15; }
        @Override public SoundEvent getEquipSound() { return SoundEvents.ITEM_ARMOR_EQUIP_IRON; }
        @Override public Ingredient getRepairIngredient() { return Ingredient.ofItems(Items.IRON_INGOT); }
        @Override public String getName() { return "shinobicore:naruto_flak"; }
        @Override public float getToughness() { return 1.0f; }
        @Override public float getKnockbackResistance() { return 0.0f; }
    };
}