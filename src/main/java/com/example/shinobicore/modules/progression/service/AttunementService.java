package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.config.ProgressionConfig;
import com.example.shinobicore.modules.progression.data.AttunementRegistry;
import com.example.shinobicore.modules.progression.event.ElementAttunedEvent;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Optional;

public final class AttunementService {
    private static CoreEvents events;

    private AttunementService() {}

    public static void init(CoreEvents coreEvents) {
        events = coreEvents;
        ShinobiLogger.module("progression", "AttunementService initialized");
    }

    public static int getFreeAffinityCount(ServerPlayerEntity player) {
        int count = ProgressionConfig.get().attunement.freeAffinityCount;
        // ClanApi may grant extra affinities (Sprint 2)
        // CoreServices.get(ClanApi.class).ifPresent(clan -> ...);
        return count;
    }

    public static boolean isFreeAttunementAvailable(ServerPlayerEntity player) {
        Optional<ProgressionComponent> opt = ProgressionComponentKey.get(player);
        if (opt.isEmpty()) return false;
        return opt.get().getUnlockedElementCount() < getFreeAffinityCount(player);
    }

    public static int getControlLevel(ServerPlayerEntity player) {
        return StatService.getStatLevel(player, "control");
    }

    public static boolean attemptAttunement(
            ServerPlayerEntity player, String elementId, boolean miniGameSuccess) {

        Optional<ProgressionComponent> opt = ProgressionComponentKey.get(player);
        if (opt.isEmpty()) return false;
        ProgressionComponent comp = opt.get();

        if (AttunementRegistry.get(elementId).isEmpty()) {
            ShinobiLogger.module("progression", "Unknown element: " + elementId);
            return false;
        }

        if (comp.isElementUnlocked(elementId)) return false;

        // Combined elements require components unlocked
        if (!AttunementRegistry.hasComponentsUnlocked(
                comp.getUnlockedElements(), elementId)) {
            ShinobiLogger.module("progression",
                "Combined element components not unlocked: " + elementId);
            return false;
        }

        int freeCount = getFreeAffinityCount(player);
        int unlockedCount = comp.getUnlockedElementCount();

        // Free affinity: no SP, no control, no mini-game
        if (unlockedCount < freeCount) {
            comp.unlockElement(elementId);
            events.publish(new ElementAttunedEvent(player, elementId));
            ProgressionStateSyncPacket.sendTo(player);
            ShinobiLogger.module("progression",
                player.getName().getString() + " attuned free element: " + elementId);
            return true;
        }

        // Paid attunement requires mini-game success
        if (!miniGameSuccess) {
            ShinobiLogger.module("progression",
                "Attunement failed (mini-game): " + elementId);
            return false;
        }

        ProgressionConfig cfg = ProgressionConfig.get();
        int elementIndex = unlockedCount - freeCount;
        int spCost = ProgressionFormula.attunementSpCost(elementIndex, cfg);
        int controlReq = ProgressionFormula.attunementControlRequired(elementIndex, cfg);

        if (!SpService.spendSp(player, spCost, "attunement:" + elementId)) {
            return false;
        }

        int control = getControlLevel(player);
        if (control < controlReq) {
            ShinobiLogger.module("progression",
                "Control too low for attunement: " + control + " < " + controlReq);
            // Refund SP since control check failed after spend
            SpService.addSp(player, spCost);
            return false;
        }

        comp.unlockElement(elementId);
        events.publish(new ElementAttunedEvent(player, elementId));
        ProgressionStateSyncPacket.sendTo(player);
        ShinobiLogger.module("progression",
            player.getName().getString() + " attuned element: " + elementId);
        return true;
    }

    public static void setAttunementProgress(
            ServerPlayerEntity player, String elementId, float progress) {
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            comp.setAttunementProgress(elementId, Math.max(0, Math.min(1, progress)));
        });
    }
}