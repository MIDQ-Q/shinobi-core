package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.config.ProgressionConfig;
import com.example.shinobicore.modules.progression.event.ReputationChangedEvent;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Optional;

public final class ReputationService {
    private static CoreEvents events;

    private ReputationService() {}

    public static void init(CoreEvents coreEvents) {
        events = coreEvents;
        ShinobiLogger.module("progression", "ReputationService initialized");
    }

    public static int getReputation(ServerPlayerEntity player, String factionId) {
        return ProgressionComponentKey.get(player)
            .map(c -> c.getReputation(factionId))
            .orElse(0);
    }

    public static void addReputation(
            ServerPlayerEntity player, String factionId, int amount) {
        if (factionId == null || factionId.isEmpty()) return;
        Optional<ProgressionComponent> opt = ProgressionComponentKey.get(player);
        if (opt.isEmpty()) return;

        ProgressionComponent comp = opt.get();
        ProgressionConfig cfg = ProgressionConfig.get();

        int old = comp.getReputation(factionId);
        int newVal = old + amount;
        int clamped = Math.max(cfg.reputation.minReputation,
            Math.min(cfg.reputation.maxReputation, newVal));

        comp.setReputation(factionId, clamped);
        events.publish(new ReputationChangedEvent(player, factionId, old, clamped));
        ProgressionStateSyncPacket.sendTo(player);
    }

    public static void setReputation(
            ServerPlayerEntity player, String factionId, int value) {
        if (factionId == null || factionId.isEmpty()) return;
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            ProgressionConfig cfg = ProgressionConfig.get();
            int old = comp.getReputation(factionId);
            int clamped = Math.max(cfg.reputation.minReputation,
                Math.min(cfg.reputation.maxReputation, value));
            comp.setReputation(factionId, clamped);
            events.publish(new ReputationChangedEvent(player, factionId, old, clamped));
            ProgressionStateSyncPacket.sendTo(player);
        });
    }

    public static void resetFaction(
            ServerPlayerEntity player, String factionId) {
        setReputation(player, factionId, 0);
    }
}