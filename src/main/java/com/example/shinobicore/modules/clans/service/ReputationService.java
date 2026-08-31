package com.example.shinobicore.modules.clans.service;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.clans.component.ClanComponent;
import com.example.shinobicore.modules.clans.component.ClanComponentKey;
import com.example.shinobicore.modules.clans.event.ReputationChangedEvent;
import net.minecraft.server.network.ServerPlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

public final class ReputationService {

    public static void init() {}

    public static void addReputation(ServerPlayerEntity player, String factionId, int amount) {
        Optional<ClanComponent> compOpt = ClanComponentKey.get(player);
        if (compOpt.isEmpty()) return;

        ClanComponent comp = compOpt.get();
        int oldRep = comp.getReputation(factionId);
        int newRep = oldRep + amount;
        comp.setReputation(factionId, newRep);

        CoreEvents.publish(new ReputationChangedEvent(player, factionId, oldRep, newRep));
    }

    public static void setReputation(ServerPlayerEntity player, String factionId, int value) {
        Optional<ClanComponent> compOpt = ClanComponentKey.get(player);
        if (compOpt.isEmpty()) return;

        ClanComponent comp = compOpt.get();
        int oldRep = comp.getReputation(factionId);
        comp.setReputation(factionId, value);

        CoreEvents.publish(new ReputationChangedEvent(player, factionId, oldRep, value));
    }

    public static void resetAll(ServerPlayerEntity player) {
        Optional<ClanComponent> compOpt = ClanComponentKey.get(player);
        if (compOpt.isEmpty()) return;

        ClanComponent comp = compOpt.get();
        Map<String, Integer> all = new HashMap<>(comp.getAllReputations());

        for (Map.Entry<String, Integer> entry : all.entrySet()) {
            comp.setReputation(entry.getKey(), 0);
            CoreEvents.publish(new ReputationChangedEvent(player, entry.getKey(), entry.getValue(), 0));
        }
    }

    public static void syncToClient(ServerPlayerEntity player) {
        com.example.shinobicore.modules.clans.network.ClansPackets.sendClanState(player);
    }
}