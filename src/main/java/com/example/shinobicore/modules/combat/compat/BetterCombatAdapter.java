package com.example.shinobicore.modules.combat.compat;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.common.WeaponClass;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.item.ItemStack;

public final class BetterCombatAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    private BetterCombatAdapter() {}

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("bettercombat")) {
            enabled = true;
            status = "loaded";
            ShinobiLogger.module("combat", "Better Combat detected, delegating melee.");
        } else {
            enabled = false;
            status = "not installed";
            ShinobiLogger.error("combat", "Better Combat NOT installed. Adapter disabled.", null);
        }
    }

    public static boolean isEnabled() { return enabled; }
    public static String getStatus() { return status; }

    public static WeaponClass resolveWeaponClass(ItemStack stack) {
        if (!enabled || stack.isEmpty()) return WeaponClass.UNARMED;
        String itemId = stack.getItem().getTranslationKey();
        if (itemId.contains("katana")) return WeaponClass.KATANA;
        if (itemId.contains("kunai")) return WeaponClass.KUNAI;
        if (itemId.contains("shuriken")) return WeaponClass.SHURIKEN;
        return WeaponClass.UNARMED;
    }
}