package com.example.shinobicore.jutsu.data;

import com.google.gson.JsonObject;
import java.util.Map;

/**
 * Immutable data model for a jutsu parsed from JSON.
 * HLD: Section 2.10 (JSON contract)
 */
public record JutsuDefinition(
    String id,
    String name,
    String category,
    String element,
    String rank,
    String behavior,
    String behaviorClass,
    JsonObject params,
    JsonObject visuals,
    Map<String, Integer> requirements,
    float baseCost,
    float baseDamage,
    float strain,
    boolean chargeable,
    String requiresDojutsu,
    String requiresScroll
) {
    public boolean hasNature() {
        return element != null && !element.isEmpty();
    }

    public boolean hasCustomBehavior() {
        return behaviorClass != null && !behaviorClass.isEmpty();
    }
}