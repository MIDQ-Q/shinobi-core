package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.config.ProgressionConfig;
import com.example.shinobicore.modules.progression.event.JutsuLevelChangedEvent;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Optional;

public final class JutsuMasteryService {
    private static CoreEvents events;

    private JutsuMasteryService() {}

    public static void init(CoreEvents coreEvents) {
        events = coreEvents;
        ShinobiLogger.module("progression", "JutsuMasteryService initialized");
    }

    public static int getJutsuLevel(ServerPlayerEntity player, String jutsuId) {
        return ProgressionComponentKey.get(player)
            .map(c -> c.getJutsuLevel(jutsuId))
            .orElse(0);
    }

    public static int getJutsuUses(ServerPlayerEntity player, String jutsuId) {
        return ProgressionComponentKey.get(player)
            .map(c -> c.getJutsuUses(jutsuId))
            .orElse(0);
    }

    public static void addJutsuUse(ServerPlayerEntity player, String jutsuId) {
        if (jutsuId == null || jutsuId.isEmpty()) return;
        Optional<ProgressionComponent> opt = ProgressionComponentKey.get(player);
        if (opt.isEmpty()) return;

        ProgressionComponent comp = opt.get();
        ProgressionConfig cfg = ProgressionConfig.get();

        comp.addJutsuUse(jutsuId);
        float xpGain = cfg.jutsu.xpPerUse;
        comp.addJutsuXp(jutsuId, xpGain);

        checkJutsuLevelUp(player, comp, jutsuId, cfg);
    }

    public static void addJutsuXpFromDamage(
            ServerPlayerEntity player, String jutsuId, float damage) {
        if (jutsuId == null || damage <= 0) return;
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            ProgressionConfig cfg = ProgressionConfig.get();
            float xpGain = damage * cfg.jutsu.xpPerDamage;
            comp.addJutsuXp(jutsuId, xpGain);
            checkJutsuLevelUp(player, comp, jutsuId, cfg);
        });
    }

    public static void addJutsuXpFromKill(ServerPlayerEntity player, String jutsuId) {
        if (jutsuId == null) return;
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            ProgressionConfig cfg = ProgressionConfig.get();
            comp.addJutsuXp(jutsuId, cfg.jutsu.xpPerKill);
            checkJutsuLevelUp(player, comp, jutsuId, cfg);
        });
    }

    private static void checkJutsuLevelUp(
            ServerPlayerEntity player, ProgressionComponent comp,
            String jutsuId, ProgressionConfig cfg) {

        int currentLevel = comp.getJutsuLevel(jutsuId);
        if (currentLevel >= cfg.jutsu.maxLevel) return;

        float currentXp = comp.getJutsuXp(jutsuId);
        int xpNeeded = ProgressionFormula.xpForJutsuLevel(currentLevel + 1, cfg);

        while (currentXp >= xpNeeded && currentLevel < cfg.jutsu.maxLevel) {
            currentXp -= xpNeeded;
            int oldLevel = currentLevel;
            currentLevel++;
            comp.setJutsuLevel(jutsuId, currentLevel);
            comp.setJutsuXp(jutsuId, currentXp);

            events.publish(new JutsuLevelChangedEvent(
                player, jutsuId, oldLevel, currentLevel));
            ProgressionStateSyncPacket.sendTo(player);

            ShinobiLogger.module("progression",
                player.getName().getString() + " jutsu " + jutsuId
                + " leveled to " + currentLevel);

            if (currentLevel >= cfg.jutsu.maxLevel) break;
            xpNeeded = ProgressionFormula.xpForJutsuLevel(currentLevel + 1, cfg);
        }
    }
}