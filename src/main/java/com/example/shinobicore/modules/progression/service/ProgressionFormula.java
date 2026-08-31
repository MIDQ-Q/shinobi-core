package com.example.shinobicore.modules.progression.service;

import com.example.shinobicore.modules.progression.config.ProgressionConfig;

public final class ProgressionFormula {
    private ProgressionFormula() {}

    public static int xpForLevel(int level, ProgressionConfig cfg) {
        return (int) (cfg.xp.baseXp * Math.pow(level, cfg.xp.exponent));
    }

    public static int xpForJutsuLevel(int level, ProgressionConfig cfg) {
        return (int) (cfg.jutsu.baseJutsuXp * Math.pow(level, cfg.jutsu.jutsuXpExponent));
    }

    public static int spCostForStatLevel(int level, ProgressionConfig cfg) {
        return cfg.sp.baseSpCostPerStat + (int)(level * cfg.sp.spCostIncrementPerLevel);
    }

    public static int attunementSpCost(int elementIndex, ProgressionConfig cfg) {
        return cfg.attunement.baseAttunementSp + (elementIndex * cfg.attunement.spCostIncrement);
    }

    public static int attunementControlRequired(int elementIndex, ProgressionConfig cfg) {
        return cfg.attunement.baseControlRequired + (elementIndex * cfg.attunement.controlIncrement);
    }
}