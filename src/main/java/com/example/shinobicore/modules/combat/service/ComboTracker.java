package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.modules.combat.common.WeaponClass;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

public final class ComboTracker {
    private static ModuleContext ctx;
    private static final long COMBO_TIMEOUT_MS = 1500;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void onAttack(ServerPlayerEntity attacker, WeaponClass weaponClass) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(attacker);
        if (comp == null) return;

        long now = System.currentTimeMillis();
        if (now > comp.getComboExpireAtMs()) {
            comp.setComboStep(0);
        }

        comp.setComboStep(comp.getComboStep() + 1);
        comp.setComboExpireAtMs(now + COMBO_TIMEOUT_MS);
    }

    public static void serverTick(MinecraftServer server) {
        long now = System.currentTimeMillis();
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
            if (comp == null) continue;

            if (comp.getComboStep() > 0 && now > comp.getComboExpireAtMs()) {
                comp.resetCombo();
            }
        }
    }
}