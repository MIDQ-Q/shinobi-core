package com.example.shinobicore.dojutsu;

/**
 * Data model for a dojutsu loaded from JSON.
 * HLD: Section 7 (Dojutsu & Sensory Network)
 */
public record DojutsuDefinition(
    String id,
    String name,
    String dojutsuType,
    String clan,
    int maxStress,
    int usagePerStage
) {
    public boolean isSharingan() { return "sharingan".equals(dojutsuType); }
    public boolean isByakugan() { return "byakugan".equals(dojutsuType); }
}