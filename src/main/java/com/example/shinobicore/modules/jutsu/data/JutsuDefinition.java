package com.example.shinobicore.modules.jutsu.data;

import com.google.gson.JsonObject;
import java.util.List;
import java.util.Map;

public record JutsuDefinition(
    String id,
    String name,
    JutsuElement element,
    String behaviorId,
    float baseCost,
    int cooldownTicks,
    int prepareTicks,
    int chargeTicks,
    int releaseTicks,
    float maxChargeMultiplier,
    Requirements requirements,
    JsonObject behaviorData,
    Scaling scaling,
    VisualData visual
) {
    public record Requirements(
        int minPlayerLevel,
        List<String> elements,
        Map<String, Integer> stats,
        boolean clanJutsu,
        String treeNode,
        String scroll,
        String dojutsu
    ) {}

    public record Scaling(
        float damagePerLevel,
        float costReductionPerLevel,
        int cooldownReductionPerLevel
    ) {}

    public record VisualData(
        List<String> castHandSeals,
        String particleColor,
        String soundCast,
        String soundImpact
    ) {}
}