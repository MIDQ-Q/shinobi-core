package com.example.shinobicore.modules.combat.input;

import com.example.shinobicore.modules.combat.client.CombatClientState;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.network.CombatPackets;
import net.minecraft.client.MinecraftClient;

public final class CombatInputHandler {

    public static void tick() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null || client.world == null) return;

        // Stance Toggle
        while (CombatKeyBindings.stanceToggle.wasPressed()) {
            Stance next = (CombatClientState.getCurrentStance() == Stance.AGGRESSIVE) ? Stance.DEFENSIVE : Stance.AGGRESSIVE;
            CombatClientState.setCurrentStance(next);
            CombatPackets.sendStanceChange(next.ordinal());
        }

        // Sheath Toggle
        while (CombatKeyBindings.sheathToggle.wasPressed()) {
            CombatClientState.setSheathed(!CombatClientState.isSheathed());
            CombatPackets.sendSheathToggle();
        }

        // Kick
        while (CombatKeyBindings.kick.wasPressed()) {
            CombatPackets.sendKick();
        }

        // Quick Slot
        while (CombatKeyBindings.quickSlot.wasPressed()) {
            CombatPackets.sendQuickSlotCycle();
        }
    }
}