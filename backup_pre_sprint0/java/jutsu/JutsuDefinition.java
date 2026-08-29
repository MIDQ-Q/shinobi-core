package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonObject;
import java.util.Map;
import java.util.List;

/**
 * S0-03: Technique definition.
 * Contains new S0-03 fields (tier, stamina, cast_time, etc.)
 * Legacy fields are kept for backwards compatibility with existing code.
 */
public record JutsuDefinition(
    // === S0-03 NEW FIELDS ===
    String id,
    String name,
    int tier,
    ElementType element,
    float chakraCost,
    float staminaCost,
    float castTime,
    boolean chargeable,
    float chargeMax,
    Map<String, Integer> requires,
    List<String> tags,
    String visual,
    String sfx,
    boolean requiresTeacher,
    String requiresScroll,
    
    // === LEGACY FIELDS (kept for compilation) ===
    String category,
    String type,
    String behaviorClass,
    JsonObject params,
    float baseDamage,
    float strain,
    int requiredUsesForFullProficiency,
    String requiresDojutsu
) {
    // Aliases for legacy code
    public boolean hasNature() { return element != null; }
    public ElementType nature() { return element; }
    public float baseCost() { return chakraCost; }
    public Map<String, Integer> requirements() { return requires; }
}