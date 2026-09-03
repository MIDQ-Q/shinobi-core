package com.example.shinobicore.config;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Central configuration manager for ShinobiCore.
 * Loads all config sections from a single JSON file.
 */
public final class ShinobiCoreConfig {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static Path configPath;
    private static boolean loaded = false;
    
    // Config sections
    public static class Chakra {
        public float baseChakra = 100.0f;
        public float chakraPerReserveLevel = 12.0f;
        public float baseRegenPerSecond = 4.0f;
        public float regenPerControlLevel = 0.15f;
        public float chakraModeDrainPerSecond = 2.0f;
        public float meditationRegenMultiplier = 2.5f;
        public int exhaustionDurationTicks = 200;
    }
    
    public static class Combat {
        public float taijutsuBaseDamage = 2.0f;
        public float taijutsuDamagePerLevel = 0.3f;
        public float chakraModeDamageMult = 1.2f;
        public float chakraModeSpeedMult = 1.15f;
        public int strongFistUnlockLevel = 50;
    }
    
    public static class Progression {
        public int xpBase = 100;
        public int xpPerLevel = 25;
        public int spPerLevelUp = 1;
        public int maxStatLevel = 100;
    }
    
    // Instances
    public static Chakra chakra = new Chakra();
    public static Combat combat = new Combat();
    public static Progression progression = new Progression();
    
    private ShinobiCoreConfig() {}
    
    /**
     * Initialize and load configuration.
     */
    public static void init() {
        configPath = FabricLoader.getInstance().getConfigDir()
                .resolve("shinobicore").resolve("shinobicore.json");
        load();
    }
    
    /**
     * Load configuration from file.
     */
    @SuppressWarnings("unchecked")
    public static void load() {
        try {
            if (!Files.exists(configPath)) {
                Files.createDirectories(configPath.getParent());
                save();
                ShinobiLogger.module("config", "Created default config at: " + configPath);
            } else {
                try (FileReader reader = new FileReader(configPath.toFile())) {
                    Map<String, Object> root = GSON.fromJson(reader, Map.class);
                    if (root != null) {
                        loadSection(root, "chakra", chakra);
                        loadSection(root, "combat", combat);
                        loadSection(root, "progression", progression);
                    }
                }
                save(); // Write back with any new defaults
            }
            loaded = true;
            ShinobiLogger.module("config", "Config loaded successfully");
        } catch (Exception e) {
            ShinobiLogger.exception("config", "Failed to load config, using defaults", e);
            resetToDefaults();
            loaded = true;
        }
    }
    
    @SuppressWarnings("unchecked")
    private static <T> void loadSection(Map<String, Object> root, String sectionName, T sectionObj) {
        Object sectionData = root.get(sectionName);
        if (sectionData instanceof Map) {
            Map<String, Object> data = (Map<String, Object>) sectionData;
            // Simple field mapping - in production use proper JSON binding
            if (sectionObj instanceof Chakra c) {
                if (data.containsKey("baseChakra")) c.baseChakra = getFloat(data, "baseChakra", c.baseChakra);
                if (data.containsKey("chakraPerReserveLevel")) c.chakraPerReserveLevel = getFloat(data, "chakraPerReserveLevel", c.chakraPerReserveLevel);
                if (data.containsKey("baseRegenPerSecond")) c.baseRegenPerSecond = getFloat(data, "baseRegenPerSecond", c.baseRegenPerSecond);
            } else if (sectionObj instanceof Combat c) {
                if (data.containsKey("taijutsuBaseDamage")) c.taijutsuBaseDamage = getFloat(data, "taijutsuBaseDamage", c.taijutsuBaseDamage);
                if (data.containsKey("taijutsuDamagePerLevel")) c.taijutsuDamagePerLevel = getFloat(data, "taijutsuDamagePerLevel", c.taijutsuDamagePerLevel);
            } else if (sectionObj instanceof Progression p) {
                if (data.containsKey("xpBase")) p.xpBase = getInt(data, "xpBase", p.xpBase);
                if (data.containsKey("xpPerLevel")) p.xpPerLevel = getInt(data, "xpPerLevel", p.xpPerLevel);
            }
        }
    }
    
    /**
     * Save configuration to file.
     */
    public static void save() {
        try {
            Files.createDirectories(configPath.getParent());
            Map<String, Object> root = new LinkedHashMap<>();
            root.put("chakra", serializeSection(chakra));
            root.put("combat", serializeSection(combat));
            root.put("progression", serializeSection(progression));
            
            try (FileWriter writer = new FileWriter(configPath.toFile())) {
                GSON.toJson(root, writer);
            }
        } catch (Exception e) {
            ShinobiLogger.exception("config", "Failed to save config", e);
        }
    }
    
    private static Map<String, Object> serializeSection(Object section) {
        Map<String, Object> map = new LinkedHashMap<>();
        if (section instanceof Chakra c) {
            map.put("baseChakra", c.baseChakra);
            map.put("chakraPerReserveLevel", c.chakraPerReserveLevel);
            map.put("baseRegenPerSecond", c.baseRegenPerSecond);
            map.put("regenPerControlLevel", c.regenPerControlLevel);
            map.put("chakraModeDrainPerSecond", c.chakraModeDrainPerSecond);
            map.put("meditationRegenMultiplier", c.meditationRegenMultiplier);
            map.put("exhaustionDurationTicks", c.exhaustionDurationTicks);
        } else if (section instanceof Combat c) {
            map.put("taijutsuBaseDamage", c.taijutsuBaseDamage);
            map.put("taijutsuDamagePerLevel", c.taijutsuDamagePerLevel);
            map.put("chakraModeDamageMult", c.chakraModeDamageMult);
            map.put("chakraModeSpeedMult", c.chakraModeSpeedMult);
            map.put("strongFistUnlockLevel", c.strongFistUnlockLevel);
        } else if (section instanceof Progression p) {
            map.put("xpBase", p.xpBase);
            map.put("xpPerLevel", p.xpPerLevel);
            map.put("spPerLevelUp", p.spPerLevelUp);
            map.put("maxStatLevel", p.maxStatLevel);
        }
        return map;
    }
    
    /**
     * Reset all config to defaults.
     */
    public static void resetToDefaults() {
        chakra = new Chakra();
        combat = new Combat();
        progression = new Progression();
    }
    
    private static float getFloat(Map<String, Object> data, String key, float def) {
        Object v = data.get(key);
        if (v instanceof Number) return ((Number) v).floatValue();
        return def;
    }
    
    private static int getInt(Map<String, Object> data, String key, int def) {
        Object v = data.get(key);
        if (v instanceof Number) return ((Number) v).intValue();
        return def;
    }
    
    public static boolean isLoaded() {
        return loaded;
    }
    
    public static Path getConfigPath() {
        return configPath;
    }
}