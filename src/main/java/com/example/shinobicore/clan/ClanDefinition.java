package com.example.shinobicore.clan;

import com.example.shinobicore.stat.ElementType;
import java.util.List;
import java.util.Map;

public record ClanDefinition(
    java.util.Map<String, Float> bonuses,
    String id,
    String name,
    ElementType affinity,
    int extraAffinityCount,
    Map<String, Integer> statBonuses,
    Map<String, Integer> natureBonuses,
    Map<String, Float> costMultiplier,
    float fatigueMultiplier,
    float reserveBonus,
    String dojutsuHook,
    int chakraCap,
    List<String> startingJutsu
) {
    public boolean hasDojutsu() {
        return dojutsuHook != null && !dojutsuHook.isEmpty();
    }
}