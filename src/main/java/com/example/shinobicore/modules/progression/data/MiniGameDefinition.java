package com.example.shinobicore.modules.progression.data;

import java.util.Map;

public record MiniGameDefinition(
    String id,
    String type,
    Map<String, Float> params,
    int rewardXp,
    String rewardStat,
    String rewardElement
) {}