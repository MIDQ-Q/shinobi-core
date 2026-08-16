package com.example.shinobicore.stat;

/**
 * S0-01: Server-side attribute registry.
 * All attributes stored on server. Client receives only display values via delta-sync.
 */
public enum AttributeType {
    MAX_CHAKRA("max_chakra", 100f, 99999f, false),
    CHAKRA("chakra", 100f, 99999f, true),
    MAX_STAMINA("max_stamina", 100f, 99999f, false),
    STAMINA("stamina", 100f, 99999f, true),
    CHAKRA_REGEN("chakra_regen", 1.0f, 100f, false),
    STAMINA_REGEN("stamina_regen", 2.0f, 100f, false),
    CONTROL("control", 0f, 100f, false),
    MASTERY("mastery", 0f, 100f, false),
    CAST_SPEED("cast_speed", 1.0f, 10f, false),
    SENSOR_TIER("sensor_tier", 0f, 5f, false),
    DOJUTSU_STATE("dojutsu_state", 0f, 10f, true);

    private final String id;
    private final float defaultValue;
    private final float maxValue;
    private final boolean volatileAttr;

    AttributeType(String id, float defaultValue, float maxValue, boolean volatileAttr) {
        this.id = id;
        this.defaultValue = defaultValue;
        this.maxValue = maxValue;
        this.volatileAttr = volatileAttr;
    }

    public String getId() { return id; }
    public float getDefaultValue() { return defaultValue; }
    public float getMaxValue() { return maxValue; }
    public boolean isVolatile() { return volatileAttr; }

    public static AttributeType fromId(String id) {
        for (AttributeType a : values()) {
            if (a.id.equals(id)) return a;
        }
        return null;
    }
}