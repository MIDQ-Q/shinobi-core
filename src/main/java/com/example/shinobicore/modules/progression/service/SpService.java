package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.event.SpGainedEvent;
import com.example.shinobicore.modules.progression.event.SpSpentEvent;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Optional;

public final class SpService {
    private static CoreEvents events;

    private SpService() {}

    public static void init(CoreEvents coreEvents) {
        events = coreEvents;
        ShinobiLogger.module("progression", "SpService initialized");
    }

    public static int getAvailableSp(ServerPlayerEntity player) {
        return ProgressionComponentKey.get(player)
            .map(ProgressionComponent::getAvailableSp)
            .orElse(0);
    }

    public static void addSp(ServerPlayerEntity player, int amount) {
        if (amount <= 0) return;
        Optional<ProgressionComponent> opt = ProgressionComponentKey.get(player);
        if (opt.isEmpty()) return;

        opt.get().addSp(amount);
        events.publish(new SpGainedEvent(player, amount));
        ProgressionStateSyncPacket.sendTo(player);
    }

    public static boolean spendSp(ServerPlayerEntity player, int amount, String reason) {
        if (amount <= 0) return false;
        Optional<ProgressionComponent> opt = ProgressionComponentKey.get(player);
        if (opt.isEmpty()) return false;

        ProgressionComponent comp = opt.get();
        if (comp.getAvailableSp() < amount) return false;

        comp.spendSp(amount);
        events.publish(new SpSpentEvent(player, amount, reason));
        ProgressionStateSyncPacket.sendTo(player);
        ShinobiLogger.module("progression",
            "SP spent: " + amount + " by " + player.getName().getString() + " reason: " + reason);
        return true;
    }
}