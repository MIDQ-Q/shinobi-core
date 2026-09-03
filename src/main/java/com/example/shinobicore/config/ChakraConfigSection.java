package com.example.shinobicore.config;

import java.util.*;

/**
 * Chakra system configuration.
 */
public class ChakraConfigSection implements ConfigSection {
    public float baseChakra = 100.0f;
    public float chakraPerReserveLevel = 12.0f;
    public float baseRegenPerSecond = 4.0f;
    public float regenPerControlLevel = 0.15f;
    public float chakraModeDrainPerSecond = 2.0f;
    public float chakraModeRegenMultiplier = 0.2f;
    public float meditationRegenMultiplier = 2.5f;
    public float meditationFatigueDecayMultiplier = 2.0f;
    public int exhaustionDurationTicks = 200; // 10 seconds
    public float chakraModeActivationMinChakra = 5.0f;
    public int chakraModeToggleCooldownTicks = 20;

    @Override
    public String id() { return "chakra"; }

    @Override
    public void load(Map<String, Object> data) {
        baseChakra = getFloat(data, "baseChakra", baseChakra);
        chakraPerReserveLevel = getFloat(data, "chakraPerReserveLevel", chakraPerReserveLevel);
        baseRegenPerSecond = getFloat(data, "baseRegenPerSecond", baseRegenPerSecond);
        regenPerControlLevel = getFloat(data, "regenPerControlLevel", regenPerControlLevel);
        chakraModeDrainPerSecond = getFloat(data, "chakraModeDrainPerSecond", chakraModeDrainPerSecond);
        chakraModeRegenMultiplier = getFloat(data, "chakraModeRegenMultiplier", chakraModeRegenMultiplier);
        meditationRegenMultiplier = getFloat(data, "meditationRegenMultiplier", meditationRegenMultiplier);
        meditationFatigueDecayMultiplier = getFloat(data, "meditationFatigueDecayMultiplier", meditationFatigueDecayMultiplier);
        exhaustionDurationTicks = getInt(data, "exhaustionDurationTicks", exhaustionDurationTicks);
        chakraModeActivationMinChakra = getFloat(data, "chakraModeActivationMinChakra", chakraModeActivationMinChakra);
        chakraModeToggleCooldownTicks = getInt(data, "chakraModeToggleCooldownTicks", chakraModeToggleCooldownTicks);
    }

    @Override
    public Map<String, Object> save() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("baseChakra", baseChakra);
        data.put("chakraPerReserveLevel", chakraPerReserveLevel);
        data.put("baseRegenPerSecond", baseRegenPerSecond);
        data.put("regenPerControlLevel", regenPerControlLevel);
        data.put("chakraModeDrainPerSecond", chakraModeDrainPerSecond);
        data.put("chakraModeRegenMultiplier", chakraModeRegenMultiplier);
        data.put("meditationRegenMultiplier", meditationRegenMultiplier);
        data.put("meditationFatigueDecayMultiplier", meditationFatigueDecayMultiplier);
        data.put("exhaustionDurationTicks", exhaustionDurationTicks);
        data.put("chakraModeActivationMinChakra", chakraModeActivationMinChakra);
        data.put("chakraModeToggleCooldownTicks", chakraModeToggleCooldownTicks);
        return data;
    }

    @Override
    public List<String> validate() {
        List<String> warnings = new ArrayList<>();
        if (baseChakra < 1) warnings.add("chakra.baseChakra < 1, using minimum 1");
        if (baseRegenPerSecond < 0) warnings.add("chakra.baseRegenPerSecond < 0");
        if (exhaustionDurationTicks < 0) warnings.add("chakra.exhaustionDurationTicks < 0");
        return warnings;
    }

    @Override
    public void resetToDefaults() {
        baseChakra = 100.0f;
        chakraPerReserveLevel = 12.0f;
        baseRegenPerSecond = 4.0f;
        regenPerControlLevel = 0.15f;
        chakraModeDrainPerSecond = 2.0f;
        chakraModeRegenMultiplier = 0.2f;
        meditationRegenMultiplier = 2.5f;
        meditationFatigueDecayMultiplier = 2.0f;
        exhaustionDurationTicks = 200;
        chakraModeActivationMinChakra = 5.0f;
        chakraModeToggleCooldownTicks = 20;
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