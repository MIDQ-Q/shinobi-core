package com.example.shinobicore.modules.combat.input;

import com.example.shinobicore.modules.combat.client.CombatClientState;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.network.CombatPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;

public final class CombatInputDispatcher {

    public static ActionResult onUseItem(ClientPlayerEntity player, Hand hand) {
        if (hand != Hand.MAIN_HAND) return ActionResult.PASS;
        if (!CombatClientState.isInCombatContext()) {
            return ActionResult.PASS; // Let vanilla handle eating, bows, etc.
        }

        ItemStack mainHand = player.getMainHandStack();
        String itemId = mainHand.getItem().getTranslationKey();

        // Priority 1: Throw (if holding throwable)
        if (itemId.contains("shuriken") || itemId.contains("kunai")) {
            CombatPackets.sendThrow(player.getYaw(), player.getPitch());
            return ActionResult.SUCCESS;
        }

        // Priority 2: Parry (Defensive stance)
        if (CombatClientState.getCurrentStance() == Stance.DEFENSIVE) {
            CombatPackets.sendParryAttempt(System.currentTimeMillis());
            return ActionResult.SUCCESS;
        }

        // Priority 3: Block (Aggressive stance + melee)
        if (CombatClientState.getCurrentStance() == Stance.AGGRESSIVE && !itemId.contains("shuriken") && !itemId.contains("kunai")) {
            CombatPackets.sendBlockStart();
            return ActionResult.SUCCESS;
        }

        // Priority 4: Sheath toggle (if katana and sheathed, quick draw)
        if (CombatClientState.isSheathed() && itemId.contains("katana")) {
            CombatPackets.sendSheathToggle();
            return ActionResult.SUCCESS;
        }

        return ActionResult.PASS;
    }
}