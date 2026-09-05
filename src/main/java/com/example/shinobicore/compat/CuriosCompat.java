package com.example.shinobicore.compat;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.entity.player.PlayerInventory;
import net.minecraft.item.ItemStack;
import net.minecraft.screen.slot.Slot;
import top.theillusivec4.curios.api.CuriosApi;
import top.theillusivec4.curios.api.type.inventory.ICurioStacksHandler;
import top.theillusivec4.curios.api.type.inventory.IDynamicStackHandler;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public final class CuriosCompat {
    private static Boolean cached = null;
    
    public static boolean isLoaded() {
        if (cached == null) {
            cached = FabricLoader.getInstance().isModLoaded("curios");
            if (cached) {
                ShinobiCore.LOGGER.info("[CuriosCompat] Curios API detected - artifact slots enabled");
            } else {
                ShinobiCore.LOGGER.info("[CuriosCompat] Curios API not found - artifact slots disabled");
            }
        }
        return cached;
    }
    
    public static List<ArtifactSlotInfo> getArtifactSlots() {
        List<ArtifactSlotInfo> slots = new ArrayList<>();
        if (!isLoaded()) return slots;
        
        // Standard artifact slot types from Artifacts mod
        slots.add(new ArtifactSlotInfo("necklace", "Necklace", 0xFFD78AFF));
        slots.add(new ArtifactSlotInfo("ring", "Ring", 0xFFFF9EC4));
        slots.add(new ArtifactSlotInfo("belt", "Belt", 0xFF8AE08A));
        slots.add(new ArtifactSlotInfo("head", "Head", 0xFF7EB7FF));
        slots.add(new ArtifactSlotInfo("hands", "Hands", 0xFFFFD75E));
        slots.add(new ArtifactSlotInfo("feet", "Feet", 0xFF9A8FA6));
        
        return slots;
    }
    
    public static ItemStack getArtifactStack(net.minecraft.entity.player.PlayerEntity player, String slotType, int index) {
        if (!isLoaded()) return ItemStack.EMPTY;
        try {
            Optional<ICurioStacksHandler> handler = CuriosApi.getCuriosInventory(player)
                .map(h -> h.getCurios().get(slotType));
            if (handler.isPresent()) {
                IDynamicStackHandler stacks = handler.get().getStacks();
                if (index < stacks.getSlots()) {
                    return stacks.getStackInSlot(index);
                }
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[CuriosCompat] Error getting artifact stack", e);
        }
        return ItemStack.EMPTY;
    }
    
    public static void setArtifactStack(net.minecraft.entity.player.PlayerEntity player, String slotType, int index, ItemStack stack) {
        if (!isLoaded()) return;
        try {
            Optional<ICurioStacksHandler> handler = CuriosApi.getCuriosInventory(player)
                .map(h -> h.getCurios().get(slotType));
            if (handler.isPresent()) {
                IDynamicStackHandler stacks = handler.get().getStacks();
                if (index < stacks.getSlots()) {
                    stacks.setStackInSlot(index, stack);
                }
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[CuriosCompat] Error setting artifact stack", e);
        }
    }
    
    public static class ArtifactSlotInfo {
        public final String id;
        public final String displayName;
        public final int accentColor;
        
        public ArtifactSlotInfo(String id, String displayName, int accentColor) {
            this.id = id;
            this.displayName = displayName;
            this.accentColor = accentColor;
        }
    }
}