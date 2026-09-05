package com.example.shinobicore.jutsu.core;

import com.example.shinobicore.jutsu.enums.EffectType;
import com.example.shinobicore.jutsu.enums.EffectSubType;
import java.util.Map;

/**
 * Определение эффекта техники.
 */
public class EffectDefinition {
    private final EffectType type;
    private final EffectSubType subType;
    private final Map<String, Object> params;

    public EffectDefinition(EffectType type, EffectSubType subType, Map<String, Object> params) {
        this.type = type;
        this.subType = subType;
        this.params = params;
    }

    public EffectType getType() { return type; }
    public EffectSubType getSubType() { return subType; }
    public Map<String, Object> getParams() { return params; }

    public double getDouble(String key, double defaultValue) {
        Object val = params.get(key);
        if (val instanceof Number) return ((Number) val).doubleValue();
        return defaultValue;
    }

    public int getInt(String key, int defaultValue) {
        Object val = params.get(key);
        if (val instanceof Number) return ((Number) val).intValue();
        return defaultValue;
    }

    public boolean getBoolean(String key, boolean defaultValue) {
        Object val = params.get(key);
        if (val instanceof Boolean) return (Boolean) val;
        return defaultValue;
    }

    public String getString(String key, String def) {
        Object v = params.get(key);
        return v == null ? def : v.toString();
    }
}
