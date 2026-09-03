package com.example.shinobicore.jutsu.core;

import java.util.Map;

/**
 * Определение свойства (тега) техники.
 */
public class PropertyDefinition {
    private final String id;
    private final Map<String, Object> params;

    public PropertyDefinition(String id, Map<String, Object> params) {
        this.id = id;
        this.params = params;
    }

    public String getId() { return id; }
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
}