package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.minecraft.server.network.ServerPlayerEntity;

public final class XpSourceService {
    private XpSourceService() {}

    public static void init() {
        ShinobiLogger.module("progression", "XpSourceService initialized (Single Source of Truth for XP)");
    }

    public static void awardXp(ServerPlayerEntity player, int amount, String source) {
        if (player == null || amount <= 0) return;
        // Future: Apply training post multiplier, clan bonuses, etc. here.
        LevelService.addXp(player, amount, source);
    }

    public static void awardXpFromDamage(ServerPlayerEntity player, float damage, String source) {
        int xp = (int) (damage * com.example.shinobicore.modules.progression.config.ProgressionConfig.get().xp.xpPerDamage);
        if (xp > 0) awardXp(player, xp, source);
    }
}