package com.example.shinobicore.modules.clans.data;
import java.util.List;
import java.util.Map;
public record ClanDefinition(
    String id, String name, String color, String affinity, int extraAffinityCount,
    Map<String, Integer> statBonuses, Map<String, Integer> natureBonuses,
    Map<String, Float> costMultiplier, float fatigueMultiplier, int reserveBonus,
    int chakraCap, String dojutsuHook, List<String> startingJutsu,
    List<PassiveEffect> passives, List<String> exclusiveJutsu
) {
    public record PassiveEffect(String id, String description, String effect, String element, float value) {}
    public ClanDefinition sanitize() {
        return new ClanDefinition(
            id != null ? id : "unknown", name != null ? name : "Unknown Clan",
            color != null ? color : "#FFFFFF", affinity != null ? affinity : "none", extraAffinityCount,
            statBonuses != null ? statBonuses : Map.of(), natureBonuses != null ? natureBonuses : Map.of(),
            costMultiplier != null ? costMultiplier : Map.of(), fatigueMultiplier > 0 ? fatigueMultiplier : 1.0f,
            reserveBonus, chakraCap > 0 ? chakraCap : 1000, dojutsuHook,
            startingJutsu != null ? startingJutsu : List.of(), passives != null ? passives : List.of(),
            exclusiveJutsu != null ? exclusiveJutsu : List.of()
        );
    }
}