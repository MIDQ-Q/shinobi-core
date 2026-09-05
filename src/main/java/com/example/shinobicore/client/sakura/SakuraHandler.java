package com.example.shinobicore.client.sakura;

import net.minecraft.entity.EquipmentSlot;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.entity.player.PlayerInventory;
import net.minecraft.item.ItemStack;
import net.minecraft.screen.ScreenHandler;
import net.minecraft.screen.slot.Slot;

public class SakuraHandler extends ScreenHandler {
    public final PlayerInventory inv;

    public static final int BG_W = 320;
    public static final int BG_H = 220;
    public static final int ARMOR_X  = 12;
    public static final int ARMOR_Y0 = 26;
    public static final int ARMOR_DY = 22;
    public static final int STASH_X  = 135;
    public static final int STASH_Y  = 30;
    public static final int SEP_Y    = 94;
    public static final int HOTBAR_Y = 110;

    public SakuraHandler(int syncId, PlayerInventory inv) {
        super(SakuraNetwork.TYPE, syncId);
        this.inv = inv;
        EquipmentSlot[] eq = {EquipmentSlot.HEAD, EquipmentSlot.CHEST, EquipmentSlot.LEGS, EquipmentSlot.FEET};
        for (int i = 0; i < 4; i++) {
            addSlot(new ArmorSlot(inv, 39 - i, ARMOR_X, ARMOR_Y0 + i * ARMOR_DY, eq[i]));
        }
        addSlot(new Slot(inv, 40, ARMOR_X, ARMOR_Y0 + 4 * ARMOR_DY));
        for (int r = 0; r < 3; r++)
            for (int c = 0; c < 9; c++)
                addSlot(new Slot(inv, 9 + r * 9 + c, STASH_X + c * 18, STASH_Y + r * 18));
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
            if (index < 5) {
                if (!this.insertItem(stack, 5, 41, true)) return ItemStack.EMPTY;
            } else if (index < 32) {
                if (!this.insertItem(stack, 32, 41, false)) {
                    if (!this.insertItem(stack, 0, 5, false)) return ItemStack.EMPTY;
                }
            } else {
                if (!this.insertItem(stack, 0, 5, false)) {
                    if (!this.insertItem(stack, 5, 32, false)) return ItemStack.EMPTY;
                }
            }
            if (stack.isEmpty()) slot.setStack(ItemStack.EMPTY);
            else slot.markDirty();
            if (stack.getCount() == result.getCount()) return ItemStack.EMPTY;
            slot.onTakeItem(player, stack);
        }
        return result;
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