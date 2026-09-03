package com.example.shinobicore.config;

import java.util.*;

/**
 * Progression and leveling configuration.
 */
public class ProgressionConfigSection implements ConfigSection {
    public int xpBase = 100;
    public int xpPerLevel = 25;
    public int xpSquared = 5;
    public int spPerLevelUp = 1;
    public int maxStatLevel = 100;
    public int maxJutsuLevel = 10;
    public float jutsuXpPerUse = 1.0f;
    public int attunementSpBaseCost = 3;
    public int attunementSpCostPerUnlocked = 2;
    public int attunementControlBaseRequirement = 10;
    public int attunementControlPerUnlocked = 5;

    @Override
    public String id() { return "progression"; }

    @Override
    public void load(Map<String, Object> data) {
        xpBase = getInt(data, "xpBase", xpBase);
        xpPerLevel = getInt(data, "xpPerLevel", xpPerLevel);
        xpSquared = getInt(data, "xpSquared", xpSquared);
        spPerLevelUp = getInt(data, "spPerLevelUp", spPerLevelUp);
        maxStatLevel = getInt(data, "maxStatLevel", maxStatLevel);
        maxJutsuLevel = getInt(data, "maxJutsuLevel", maxJutsuLevel);
        jutsuXpPerUse = getFloat(data, "jutsuXpPerUse", jutsuXpPerUse);
        attunementSpBaseCost = getInt(data, "attunementSpBaseCost", attunementSpBaseCost);
        attunementSpCostPerUnlocked = getInt(data, "attunementSpCostPerUnlocked", attunementSpCostPerUnlocked);
        attunementControlBaseRequirement = getInt(data, "attunementControlBaseRequirement", attunementControlBaseRequirement);
        attunementControlPerUnlocked = getInt(data, "attunementControlPerUnlocked", attunementControlPerUnlocked);
    }

    @Override
    public Map<String, Object> save() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("xpBase", xpBase);
        data.put("xpPerLevel", xpPerLevel);
        data.put("xpSquared", xpSquared);
        data.put("spPerLevelUp", spPerLevelUp);
        data.put("maxStatLevel", maxStatLevel);
        data.put("maxJutsuLevel", maxJutsuLevel);
        data.put("jutsuXpPerUse", jutsuXpPerUse);
        data.put("attunementSpBaseCost", attunementSpBaseCost);
        data.put("attunementSpCostPerUnlocked", attunementSpCostPerUnlocked);
        data.put("attunementControlBaseRequirement", attunementControlBaseRequirement);
        data.put("attunementControlPerUnlocked", attunementControlPerUnlocked);
        return data;
    }

    @Override
    public List<String> validate() {
        List<String> warnings = new ArrayList<>();
        if (maxStatLevel < 1 || maxStatLevel > 200) warnings.add("progression.maxStatLevel out of range [1, 200]");
        if (maxJutsuLevel < 1 || maxJutsuLevel > 20) warnings.add("progression.maxJutsuLevel out of range [1, 20]");
        return warnings;
    }

    @Override
    public void resetToDefaults() {
        xpBase = 100;
        xpPerLevel = 25;
        xpSquared = 5;
        spPerLevelUp = 1;
        maxStatLevel = 100;
        maxJutsuLevel = 10;
        jutsuXpPerUse = 1.0f;
        attunementSpBaseCost = 3;
        attunementSpCostPerUnlocked = 2;
        attunementControlBaseRequirement = 10;
        attunementControlPerUnlocked = 5;
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
}