package com.example.shinobicore.config;

/**
 * Base interface for all configuration sections.
 * Each section handles its own loading, saving, and validation.
 */
public interface ConfigSection {
    /**
     * Unique identifier for this config section.
     */
    String id();

    /**
     * Load configuration from the provided data map.
     * Missing fields should use defaults.
     */
    void load(java.util.Map<String, Object> data);

    /**
     * Save configuration to a data map.
     */
    java.util.Map<String, Object> save();

    /**
     * Validate all values. Returns list of warnings.
     */
    java.util.List<String> validate();

    /**
     * Reset to defaults.
     */
    void resetToDefaults();
}