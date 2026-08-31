package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.config.ProgressionConfig;
import com.example.shinobicore.modules.progression.event.LevelChangedEvent;
import com.example.shinobicore.modules.progression.event.XpGainedEvent;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Optional;

public final class LevelService {
    private static CoreEvents events;

    private LevelService() {}

    public static void init(CoreEvents coreEvents) {
        events = coreEvents;
        ShinobiLogger.module("progression", "LevelService initialized");
    }

    public static void addXp(ServerPlayerEntity player, int amount, String source) {
        if (amount <= 0) return;
        Optional<ProgressionComponent> compOpt = ProgressionComponentKey.get(player);
        if (compOpt.isEmpty()) return;

        ProgressionComponent comp = compOpt.get();
        ProgressionConfig cfg = ProgressionConfig.get();

        comp.addXp(amount);
        events.publish(new XpGainedEvent(player, amount, source));

        int nextLevel = comp.getPlayerLevel() + 1;
        int xpNeeded = ProgressionFormula.xpForLevel(nextLevel, cfg);

        while (comp.getCurrentXp() >= xpNeeded) {
            comp.subtractXp(xpNeeded);
            int oldLevel = comp.getPlayerLevel();
            comp.setPlayerLevel(nextLevel);

            SpService.addSp(player, cfg.sp.spPerLevelUp);

            events.publish(new LevelChangedEvent(player, oldLevel, nextLevel));
            ShinobiLogger.module("progression",
                player.getName().getString() + " leveled up to " + nextLevel);

            nextLevel++;
            xpNeeded = ProgressionFormula.xpForLevel(nextLevel, cfg);
        }

        ProgressionStateSyncPacket.sendTo(player);
    }

    public static void setLevel(ServerPlayerEntity player, int level) {
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            int old = comp.getPlayerLevel();
            int clamped = Math.max(1, level);
            comp.setPlayerLevel(clamped);
            comp.subtractXp(comp.getCurrentXp());
            events.publish(new LevelChangedEvent(player, old, clamped));
            ProgressionStateSyncPacket.sendTo(player);
        });
    }
}