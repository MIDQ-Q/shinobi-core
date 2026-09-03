package com.example.shinobicore.config;

import java.util.*;

/**
 * Logging configuration.
 */
public class LoggingConfigSection implements ConfigSection {
    public String level = "INFO";
    public boolean fileLogging = true;
    public int maxLogFiles = 3;
    public int maxLogFileSizeMb = 5;
    public boolean moduleFilterEnabled = false;
    public List<String> enabledModules = new ArrayList<>();
    public boolean logChakraSync = false;
    public boolean logCombatDamage = false;
    public boolean logJutsuCasts = true;
    public boolean logPacketTraffic = false;

    @Override
    public String id() { return "logging"; }

    @Override
    public void load(Map<String, Object> data) {
        level = getString(data, "level", level);
        fileLogging = getBool(data, "fileLogging", fileLogging);
        maxLogFiles = getInt(data, "maxLogFiles", maxLogFiles);
        maxLogFileSizeMb = getInt(data, "maxLogFileSizeMb", maxLogFileSizeMb);
        moduleFilterEnabled = getBool(data, "moduleFilterEnabled", moduleFilterEnabled);
        logChakraSync = getBool(data, "logChakraSync", logChakraSync);
        logCombatDamage = getBool(data, "logCombatDamage", logCombatDamage);
        logJutsuCasts = getBool(data, "logJutsuCasts", logJutsuCasts);
        logPacketTraffic = getBool(data, "logPacketTraffic", logPacketTraffic);
        Object modules = data.get("enabledModules");
        if (modules instanceof List) {
            enabledModules.clear();
            for (Object m : (List<?>) modules) {
                if (m instanceof String) enabledModules.add((String) m);
            }
        }
    }

    @Override
    public Map<String, Object> save() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("level", level);
        data.put("fileLogging", fileLogging);
        data.put("maxLogFiles", maxLogFiles);
        data.put("maxLogFileSizeMb", maxLogFileSizeMb);
        data.put("moduleFilterEnabled", moduleFilterEnabled);
        data.put("enabledModules", enabledModules);
        data.put("logChakraSync", logChakraSync);
        data.put("logCombatDamage", logCombatDamage);
        data.put("logJutsuCasts", logJutsuCasts);
        data.put("logPacketTraffic", logPacketTraffic);
        return data;
    }

    @Override
    public List<String> validate() {
        List<String> warnings = new ArrayList<>();
        if (!level.equals("TRACE") && !level.equals("DEBUG") && !level.equals("INFO")
                && !level.equals("WARN") && !level.equals("ERROR")) {
            warnings.add("logging.level invalid, defaulting to INFO");
            level = "INFO";
        }
        return warnings;
    }

    @Override
    public void resetToDefaults() {
        level = "INFO";
        fileLogging = true;
        maxLogFiles = 3;
        maxLogFileSizeMb = 5;
        moduleFilterEnabled = false;
        enabledModules.clear();
        logChakraSync = false;
        logCombatDamage = false;
        logJutsuCasts = true;
        logPacketTraffic = false;
    }

    private static String getString(Map<String, Object> data, String key, String def) {
        Object v = data.get(key);
        if (v instanceof String) return (String) v;
        return def;
    }

    private static boolean getBool(Map<String, Object> data, String key, boolean def) {
        Object v = data.get(key);
        if (v instanceof Boolean) return (Boolean) v;
        return def;
    }

    private static int getInt(Map<String, Object> data, String key, int def) {
        Object v = data.get(key);
        if (v instanceof Number) return ((Number) v).intValue();
        return def;
    }
}