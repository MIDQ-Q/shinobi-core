package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.config.ProgressionConfig;
import com.example.shinobicore.modules.progression.event.StatLevelChangedEvent;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Optional;

public final class StatService {
    public static final String[] PRIMARY_STATS = {
        "control", "ninjutsu", "taijutsu", "genjutsu",
        "medical", "space_time", "perception"
    };

    private static CoreEvents events;

    private StatService() {}

    public static void init(CoreEvents coreEvents) {
        events = coreEvents;
        ShinobiLogger.module("progression", "StatService initialized");
    }

    public static boolean isValidStat(String statId) {
        for (String s : PRIMARY_STATS) {
            if (s.equals(statId)) return true;
        }
        return false;
    }

    public static int getStatLevel(ServerPlayerEntity player, String statId) {
        if (!isValidStat(statId)) return 0;
        return ProgressionComponentKey.get(player)
            .map(c -> c.getStatLevel(statId))
            .orElse(0);
    }

    public static boolean increaseStat(ServerPlayerEntity player, String statId) {
        if (!isValidStat(statId)) {
            ShinobiLogger.module("progression", "Invalid stat: " + statId);
            return false;
        }

        Optional<ProgressionComponent> opt = ProgressionComponentKey.get(player);
        if (opt.isEmpty()) return false;

        ProgressionComponent comp = opt.get();
        ProgressionConfig cfg = ProgressionConfig.get();
        int currentLevel = comp.getStatLevel(statId);
        int maxLevel = cfg.sp.maxStatLevel;

        if (currentLevel >= maxLevel) {
            ShinobiLogger.module("progression", "Stat " + statId + " already at max");
            return false;
        }

        int spCost = ProgressionFormula.spCostForStatLevel(currentLevel, cfg);
        if (!SpService.spendSp(player, spCost, "stat:" + statId)) {
            return false;
        }

        int newLevel = currentLevel + 1;
        comp.setStatLevel(statId, newLevel);
        events.publish(new StatLevelChangedEvent(player, statId, currentLevel, newLevel));
        ProgressionStateSyncPacket.sendTo(player);

        ShinobiLogger.module("progression",
            player.getName().getString() + " raised " + statId + " to " + newLevel);
        return true;
    }

    public static void setStatLevel(ServerPlayerEntity player, String statId, int level) {
        if (!isValidStat(statId)) return;
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            int old = comp.getStatLevel(statId);
            int clamped = Math.max(0, Math.min(level, ProgressionConfig.get().sp.maxStatLevel));
            comp.setStatLevel(statId, clamped);
            events.publish(new StatLevelChangedEvent(player, statId, old, clamped));
            ProgressionStateSyncPacket.sendTo(player);
        });
    }

    public static void addStatXp(ServerPlayerEntity player, String statId, float amount) {
        if (!isValidStat(statId) || amount <= 0) return;
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            comp.addStatXp(statId, amount);
        });
    }
}