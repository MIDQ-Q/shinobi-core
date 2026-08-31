package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.CombatModule;
import net.minecraft.entity.player.PlayerInventory;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;

public final class QuickWeaponSlotService {
    private static ModuleContext ctx;
    private static final String[] CYCLE_ORDER = {"katana", "kunai", "shuriken"};

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void cycleWeapon(ServerPlayerEntity player) {
        PlayerInventory inv = player.getInventory();
        ItemStack current = player.getMainHandStack();
        String currentId = current.getItem().getTranslationKey();
        
        int currentIndex = -1;
        for (int i = 0; i < CYCLE_ORDER.length; i++) {
            if (currentId.contains(CYCLE_ORDER[i])) {
                currentIndex = i;
                break;
            }
        }

        for (int i = 1; i <= CYCLE_ORDER.length; i++) {
            int nextIndex = (currentIndex + i) % CYCLE_ORDER.length;
            String targetName = CYCLE_ORDER[nextIndex];
            
            for (int slot = 0; slot < inv.size(); slot++) {
                ItemStack stack = inv.getStack(slot);
                if (!stack.isEmpty() && stack.getItem().getTranslationKey().contains(targetName)) {
                    inv.selectedSlot = slot < 9 ? slot : inv.selectedSlot;
                    if (slot >= 9) {
                        inv.swapSlotWithHotbar(slot);
                    }
                    ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " quick-swapped to " + targetName);
                    return;
                }
            }
        }
        
        ShinobiLogger.module(CombatModule.ID, "No other combat weapons found in inventory for " + player.getName().getString());
    }
}