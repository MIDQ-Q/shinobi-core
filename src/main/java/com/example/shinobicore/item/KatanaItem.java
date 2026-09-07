package com.example.shinobicore.item;

import net.fabricmc.api.EnvType;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterials;

/**
 * Katana weapon. Variant = name of the Blockbench model file
 * in assets/shinobicore/models/item/<variant>.json
 * Visuals (glint, particles, slash anims) come from
 * assets/shinobicore/weapon_visuals/<item_id>.json (client side).
 * Damage stays in code (KenjutsuFormulas / server handlers).
 */
public class KatanaItem extends SwordItem {
    private final String variant;

    public KatanaItem(String variant) {
        super(ToolMaterials.IRON, 4, -2.0f, new Item.Settings().maxCount(1));
        this.variant = variant;
    }

    public String getVariant() { return variant; }

    @Override
    public boolean hasGlint(ItemStack stack) {
        if (FabricLoader.getInstance().getEnvironmentType() == EnvType.CLIENT
                && com.example.shinobicore.client.render.WeaponVisualRegistry.hasGlint(stack)) {
            return true;
        }
        return super.hasGlint(stack);
    }
}