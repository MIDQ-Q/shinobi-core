package com.example.shinobicore.item;

import net.minecraft.client.item.TooltipContext;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import net.minecraft.world.World;
import java.util.List;

public class ScrollItem extends Item {
    public ScrollItem(Settings settings) { super(settings); }

    public static String getJutsuId(ItemStack stack) {
        NbtCompound nbt = stack.getNbt();
        if (nbt != null && nbt.contains("JutsuId")) return nbt.getString("JutsuId");
        return null;
    }

    public static void setJutsuId(ItemStack stack, String jutsuId) {
        stack.getOrCreateNbt().putString("JutsuId", jutsuId);
    }

    @Override
    public Text getName(ItemStack stack) {
        String id = getJutsuId(stack);
        if (id != null) return Text.literal("Scroll: " + id.replace("shinobicore:", "")).formatted(Formatting.GOLD);
        return Text.literal("Empty Scroll").formatted(Formatting.GRAY);
    }

    @Override
    public void appendTooltip(ItemStack stack, World world, List<Text> tooltip, TooltipContext context) {
        String id = getJutsuId(stack);
        if (id != null) tooltip.add(Text.literal("Grants: " + id).formatted(Formatting.YELLOW));
        else tooltip.add(Text.literal("An empty scroll").formatted(Formatting.GRAY));
    }

    @Override
    public boolean hasGlint(ItemStack stack) { return getJutsuId(stack) != null; }
}