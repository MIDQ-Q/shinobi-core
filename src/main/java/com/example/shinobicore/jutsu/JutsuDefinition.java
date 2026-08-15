package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonObject;

import java.util.Map;

public record JutsuDefinition(
    String id,
    String name,
    String category,
    ElementType nature,
    String type,
    String behaviorClass,
    JsonObject params,
    float baseCost,
    float baseDamage,
    float strain,
    int requiredUsesForFullProficiency,
    Map<String, Integer> requirements,
    String requiresDojutsu,
    String requiresScroll
) {
    public boolean hasNature() {
        return nature != null;
    }
}