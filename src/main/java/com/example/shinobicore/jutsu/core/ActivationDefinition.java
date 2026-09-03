package com.example.shinobicore.jutsu.core;

import com.example.shinobicore.jutsu.enums.ActivationType;
import java.util.Map;

/**
 * Определение активации техники.
 */
public class ActivationDefinition {
    private final ActivationType type;
    private final Map<String, Object> params;

    public ActivationDefinition(ActivationType type, Map<String, Object> params) {
        this.type = type;
        this.params = params;
    }

    public ActivationType getType() { return type; }
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
}