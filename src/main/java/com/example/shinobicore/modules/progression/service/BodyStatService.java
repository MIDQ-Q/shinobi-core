package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.config.ProgressionConfig;
import com.example.shinobicore.modules.progression.event.BodyStatChangedEvent;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Optional;

public final class BodyStatService {
    public static final String[] BODY_STATS = {
        "speed", "jump", "vitality", "reserve", "endurance"
    };

    private static CoreEvents events;

    private BodyStatService() {}

    public static void init(CoreEvents coreEvents) {
        events = coreEvents;
        ShinobiLogger.module("progression", "BodyStatService initialized");
    }

    public static boolean isValidBodyStat(String statId) {
        for (String s : BODY_STATS) {
            if (s.equals(statId)) return true;
        }
        return false;
    }

    public static int getBodyStatLevel(ServerPlayerEntity player, String statId) {
        if (!isValidBodyStat(statId)) return 0;
        return ProgressionComponentKey.get(player)
            .map(c -> c.getBodyStatLevel(statId))
            .orElse(0);
    }

    public static boolean increaseBodyStat(ServerPlayerEntity player, String statId) {
        if (!isValidBodyStat(statId)) {
            ShinobiLogger.module("progression", "Invalid body stat: " + statId);
            return false;
        }

        Optional<ProgressionComponent> opt = ProgressionComponentKey.get(player);
        if (opt.isEmpty()) return false;

        ProgressionComponent comp = opt.get();
        ProgressionConfig cfg = ProgressionConfig.get();
        int currentLevel = comp.getBodyStatLevel(statId);
        int maxLevel = cfg.sp.maxBodyStatLevel;

        if (currentLevel >= maxLevel) {
            ShinobiLogger.module("progression", "Body stat " + statId + " at max");
            return false;
        }

        int spCost = ProgressionFormula.spCostForStatLevel(currentLevel, cfg);
        if (!SpService.spendSp(player, spCost, "body_stat:" + statId)) {
            return false;
        }

        int newLevel = currentLevel + 1;
        comp.setBodyStatLevel(statId, newLevel);
        events.publish(new BodyStatChangedEvent(player, statId, currentLevel, newLevel));
        ProgressionStateSyncPacket.sendTo(player);

        ShinobiLogger.module("progression",
            player.getName().getString() + " raised body stat " + statId + " to " + newLevel);
        return true;
    }

    public static void setBodyStatLevel(ServerPlayerEntity player, String statId, int level) {
        if (!isValidBodyStat(statId)) return;
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            int old = comp.getBodyStatLevel(statId);
            int clamped = Math.max(0, Math.min(level, ProgressionConfig.get().sp.maxBodyStatLevel));
            comp.setBodyStatLevel(statId, clamped);
            events.publish(new BodyStatChangedEvent(player, statId, old, clamped));
            ProgressionStateSyncPacket.sendTo(player);
        });
    }
}