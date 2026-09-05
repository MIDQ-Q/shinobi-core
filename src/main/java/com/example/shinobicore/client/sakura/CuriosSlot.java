package com.example.shinobicore.client.sakura;

import com.example.shinobicore.compat.CuriosCompat;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.screen.slot.Slot;

public class CuriosSlot extends Slot {
    private final String slotType;
    private final int curiosIndex;
    private final PlayerEntity player;
    
    public CuriosSlot(PlayerEntity player, String slotType, int curiosIndex, int x, int y) {
        super(player.getInventory(), -1, x, y); // -1 index since we handle it manually
        this.player = player;
        this.slotType = slotType;
        this.curiosIndex = curiosIndex;
    }
    
    @Override
    public ItemStack getStack() {
        return CuriosCompat.getArtifactStack(player, slotType, curiosIndex);
    }
    
    @Override
    public void setStack(ItemStack stack) {
        CuriosCompat.setArtifactStack(player, slotType, curiosIndex, stack);
        this.markDirty();
    }
    
    @Override
    public void setStackNoCallbacks(ItemStack stack) {
        this.setStack(stack);
    }
    
    @Override
    public ItemStack takeStack(int amount) {
        ItemStack current = this.getStack();
        if (current.isEmpty()) return ItemStack.EMPTY;
        ItemStack taken = current.split(amount);
        this.setStack(current);
        return taken;
    }
    
    @Override
    public boolean canInsert(ItemStack stack) {
        if (!CuriosCompat.isLoaded()) return false;
        // Check if item is valid for this slot type via Curios API
        try {
            return top.theillusivec4.curios.api.CuriosApi.getItemStackSlots(stack, player)
                .containsKey(slotType);
        } catch (Exception e) {
            return false;
        }
    }
    
    @Override
    public boolean canTakeItems(PlayerEntity playerEntity) {
        return !this.getStack().isEmpty();
    }
    
    @Override
    public int getMaxItemCount() {
        return 1;
    }
    
    @Override
    public void markDirty() {
        // Sync with Curios
    }
    
    public String getSlotType() { return slotType; }
}