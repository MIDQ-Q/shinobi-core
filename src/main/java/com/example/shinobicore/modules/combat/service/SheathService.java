package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.event.CoreEvents;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.event.CombatEvents;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;

public final class SheathService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void toggleSheath(ServerPlayerEntity player) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp == null) return;

        ItemStack mainHand = player.getMainHandStack();
        String itemId = mainHand.getItem().getTranslationKey();
        
        if (!itemId.contains("katana") && !comp.isSheathed()) {
            ShinobiLogger.module(CombatModule.ID, "Player tried to sheath non-katana item");
            return;
        }

        boolean newState = !comp.isSheathed();
        comp.setSheathed(newState);

        if (newState) {
            CoreEvents.publish(new CombatEvents.WeaponSheathedEvent(player, true, itemId));
            ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " sheathed weapon");
        } else {
            CoreEvents.publish(new CombatEvents.WeaponDrawnEvent(player, itemId));
            ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " drew weapon");
        }
    }
}