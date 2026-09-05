package com.example.shinobicore.item.artifacts;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import dev.emi.trinkets.api.SlotReference;
import dev.emi.trinkets.api.TrinketItem;
import net.minecraft.entity.LivingEntity;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Shinobi Charm: wearable trinket (Artifacts/Trinkets slot).
 * Effect: slowly restores chakra while equipped (4 chakra / 2s).
 */
public class ShinobiCharmItem extends TrinketItem {
    public ShinobiCharmItem() {
        super(new Item.Settings().maxCount(1));
    }

    @Override
    public void tick(ItemStack stack, SlotReference slot, LivingEntity entity) {
        if (entity.getWorld().isClient()) return;
        if (!(entity instanceof ServerPlayerEntity player)) return;
        if (entity.age % 40 != 0) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        float max = NinjaFormula.maxChakra(data);
        if (data.getCurrentChakra() < max) {
            data.setCurrentChakra(Math.min(max, data.getCurrentChakra() + 4));
            ShinobiCore.sendChakraSync(player);
        }
    }
}