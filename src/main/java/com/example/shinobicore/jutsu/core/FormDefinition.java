package com.example.shinobicore.jutsu.core;

import com.example.shinobicore.jutsu.enums.FormType;
import java.util.Map;

/**
 * Определение формы техники.
 */
public class FormDefinition {
    private final FormType type;
    private final Map<String, Object> params;

    public FormDefinition(FormType type, Map<String, Object> params) {
        this.type = type;
        this.params = params;
    }

    public FormType getType() { return type; }
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

    public String getString(String key, String defaultValue) {
        Object val = params.get(key);
        if (val instanceof String) return (String) val;
        return defaultValue;
    }
}