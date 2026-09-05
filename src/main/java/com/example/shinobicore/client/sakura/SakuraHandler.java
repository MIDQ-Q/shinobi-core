package com.example.shinobicore.client.sakura;

import com.example.shinobicore.compat.CuriosCompat;
import net.minecraft.entity.EquipmentSlot;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.entity.player.PlayerInventory;
import net.minecraft.item.ItemStack;
import net.minecraft.screen.ScreenHandler;
import net.minecraft.screen.slot.Slot;

import java.util.ArrayList;
import java.util.List;

public class SakuraHandler extends ScreenHandler {
    public final PlayerInventory inv;
    public final List<CuriosSlot> artifactSlots = new ArrayList<>();
    
    // ==== LAYOUT (coords relative to GUI origin) ====
    public static final int BG_W = 320;
    public static final int BG_H = 220;
    
    // Left panel: Armor + Artifacts
    public static final int ARMOR_X = 12;
    public static final int ARMOR_Y0 = 26;
    public static final int ARMOR_DY = 22;
    
    // Artifacts panel (right of armor)
    public static final int ARTIFACT_X = 60;
    public static final int ARTIFACT_Y0 = 26;
    public static final int ARTIFACT_DY = 22;
    
    // Right panel: Stash + Hotbar
    public static final int STASH_X = 135;
    public static final int STASH_Y = 30;
    public static final int SEP_Y = 94;
    public static final int HOTBAR_Y = 110;
    
    public SakuraHandler(int syncId, PlayerInventory inv) {
        super(SakuraNetwork.TYPE, syncId);
        this.inv = inv;
        
        // 0..3: armor HEAD/CHEST/LEGS/FEET
        EquipmentSlot[] eq = {EquipmentSlot.HEAD, EquipmentSlot.CHEST, EquipmentSlot.LEGS, EquipmentSlot.FEET};
        for (int i = 0; i < 4; i++) {
            addSlot(new ArmorSlot(inv, 39 - i, ARMOR_X, ARMOR_Y0 + i * ARMOR_DY, eq[i]));
        }
        
        // 4: offhand
        addSlot(new Slot(inv, 40, ARMOR_X, ARMOR_Y0 + 4 * ARMOR_DY));
        
        // 5..N: Artifact slots (Curios integration)
        if (CuriosCompat.isLoaded()) {
            List<CuriosCompat.ArtifactSlotInfo> artifacts = CuriosCompat.getArtifactSlots();
            for (int i = 0; i < artifacts.size(); i++) {
                CuriosSlot slot = new CuriosSlot(
                    inv.player,
                    artifacts.get(i).id,
                    0,
                    ARTIFACT_X,
                    ARTIFACT_Y0 + i * ARTIFACT_DY
                );
                artifactSlots.add(slot);
                addSlot(slot);
            }
        }
        
        // Stash: 9x3
        int stashStart = 5 + artifactSlots.size();
        for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 9; c++) {
                addSlot(new Slot(inv, 9 + r * 9 + c, STASH_X + c * 18, STASH_Y + r * 18));
            }
        }
        
        // Hotbar: 9 slots
        for (int i = 0; i < 9; i++) {
            addSlot(new Slot(inv, i, STASH_X + i * 18, HOTBAR_Y));
        }
    }
    
    @Override
    public boolean canUse(PlayerEntity player) { return true; }
    
    @Override
    public ItemStack quickMove(PlayerEntity player, int index) {
        ItemStack result = ItemStack.EMPTY;
        Slot slot = this.slots.get(index);
        if (slot != null && slot.hasStack()) {
            ItemStack stack = slot.getStack();
            result = stack.copy();
            
            int armorEnd = 5;
            int artifactEnd = armorEnd + artifactSlots.size();
            int stashEnd = artifactEnd + 27;
            
            if (index < armorEnd) {
                // armor/offhand -> stash/hotbar
                if (!this.insertItem(stack, artifactEnd, stashEnd + 9, true)) return ItemStack.EMPTY;
            } else if (index < artifactEnd) {
                // artifact -> stash/hotbar
                if (!this.insertItem(stack, artifactEnd, stashEnd + 9, true)) return ItemStack.EMPTY;
            } else if (index < stashEnd) {
                // stash -> hotbar, else try armor, else try artifacts
                if (!this.insertItem(stack, stashEnd, stashEnd + 9, false)) {
                    if (!this.insertItem(stack, 0, armorEnd, false)) {
                        if (!tryInsertArtifact(stack)) return ItemStack.EMPTY;
                    }
                }
            } else {
                // hotbar -> stash, else armor, else artifacts
                if (!this.insertItem(stack, artifactEnd, stashEnd, false)) {
                    if (!this.insertItem(stack, 0, armorEnd, false)) {
                        if (!tryInsertArtifact(stack)) return ItemStack.EMPTY;
                    }
                }
            }
            
            if (stack.isEmpty()) slot.setStack(ItemStack.EMPTY);
            else slot.markDirty();
            if (stack.getCount() == result.getCount()) return ItemStack.EMPTY;
            slot.onTakeItem(player, stack);
        }
        return result;
    }
    
    private boolean tryInsertArtifact(ItemStack stack) {
        if (!CuriosCompat.isLoaded()) return false;
        for (CuriosSlot slot : artifactSlots) {
            if (slot.canInsert(stack) && slot.getStack().isEmpty()) {
                slot.setStack(stack.copy());
                stack.setCount(0);
                return true;
            }
        }
        return false;
    }
    
    private static class ArmorSlot extends Slot {
        private final EquipmentSlot eq;
        public ArmorSlot(PlayerInventory inv, int index, int x, int y, EquipmentSlot eq) {
            super(inv, index, x, y);
            this.eq = eq;
        }
        @Override public int getMaxItemCount() { return 1; }
        @Override public boolean canInsert(ItemStack stack) {
            return LivingEntity.getPreferredEquipmentSlot(stack) == eq;
        }
    }
}