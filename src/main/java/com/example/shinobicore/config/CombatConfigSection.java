package com.example.shinobicore.config;

import java.util.*;

/**
 * Combat system configuration.
 */
public class CombatConfigSection implements ConfigSection {
    public float taijutsuBaseDamage = 2.0f;
    public float taijutsuDamagePerLevel = 0.3f;
    public float chakraModeDamageMult = 1.2f;
    public float chakraModeSpeedMult = 1.15f;
    public int strongFistUnlockLevel = 50;
    public float parryWindowMs = 400.0f;
    public float parryCooldownMs = 200.0f;
    public float blockStaminaPerSecond = 3.0f;
    public float blockBaseDamageReduction = 0.6f;
    public float kickStandaloneDamageMult = 1.5f;
    public float kickComboFinisherDamageMult = 1.5f;
    public int kickStandaloneCooldownMs = 900;
    public int kickComboFinisherCooldownMs = 600;

    @Override
    public String id() { return "combat"; }

    @Override
    public void load(Map<String, Object> data) {
        taijutsuBaseDamage = getFloat(data, "taijutsuBaseDamage", taijutsuBaseDamage);
        taijutsuDamagePerLevel = getFloat(data, "taijutsuDamagePerLevel", taijutsuDamagePerLevel);
        chakraModeDamageMult = getFloat(data, "chakraModeDamageMult", chakraModeDamageMult);
        chakraModeSpeedMult = getFloat(data, "chakraModeSpeedMult", chakraModeSpeedMult);
        strongFistUnlockLevel = getInt(data, "strongFistUnlockLevel", strongFistUnlockLevel);
        parryWindowMs = getFloat(data, "parryWindowMs", parryWindowMs);
        parryCooldownMs = getFloat(data, "parryCooldownMs", parryCooldownMs);
        blockStaminaPerSecond = getFloat(data, "blockStaminaPerSecond", blockStaminaPerSecond);
        blockBaseDamageReduction = getFloat(data, "blockBaseDamageReduction", blockBaseDamageReduction);
        kickStandaloneDamageMult = getFloat(data, "kickStandaloneDamageMult", kickStandaloneDamageMult);
        kickComboFinisherDamageMult = getFloat(data, "kickComboFinisherDamageMult", kickComboFinisherDamageMult);
        kickStandaloneCooldownMs = getInt(data, "kickStandaloneCooldownMs", kickStandaloneCooldownMs);
        kickComboFinisherCooldownMs = getInt(data, "kickComboFinisherCooldownMs", kickComboFinisherCooldownMs);
    }

    @Override
    public Map<String, Object> save() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("taijutsuBaseDamage", taijutsuBaseDamage);
        data.put("taijutsuDamagePerLevel", taijutsuDamagePerLevel);
        data.put("chakraModeDamageMult", chakraModeDamageMult);
        data.put("chakraModeSpeedMult", chakraModeSpeedMult);
        data.put("strongFistUnlockLevel", strongFistUnlockLevel);
        data.put("parryWindowMs", parryWindowMs);
        data.put("parryCooldownMs", parryCooldownMs);
        data.put("blockStaminaPerSecond", blockStaminaPerSecond);
        data.put("blockBaseDamageReduction", blockBaseDamageReduction);
        data.put("kickStandaloneDamageMult", kickStandaloneDamageMult);
        data.put("kickComboFinisherDamageMult", kickComboFinisherDamageMult);
        data.put("kickStandaloneCooldownMs", kickStandaloneCooldownMs);
        data.put("kickComboFinisherCooldownMs", kickComboFinisherCooldownMs);
        return data;
    }

    @Override
    public List<String> validate() {
        List<String> warnings = new ArrayList<>();
        if (parryWindowMs < 100) warnings.add("combat.parryWindowMs < 100ms may be too short");
        if (parryWindowMs > 1000) warnings.add("combat.parryWindowMs > 1000ms may be too long");
        if (blockStaminaPerSecond < 0) warnings.add("combat.blockStaminaPerSecond < 0");
        return warnings;
    }

    @Override
    public void resetToDefaults() {
        taijutsuBaseDamage = 2.0f;
        taijutsuDamagePerLevel = 0.3f;
        chakraModeDamageMult = 1.2f;
        chakraModeSpeedMult = 1.15f;
        strongFistUnlockLevel = 50;
        parryWindowMs = 400.0f;
        parryCooldownMs = 200.0f;
        blockStaminaPerSecond = 3.0f;
        blockBaseDamageReduction = 0.6f;
        kickStandaloneDamageMult = 1.5f;
        kickComboFinisherDamageMult = 1.5f;
        kickStandaloneCooldownMs = 900;
        kickComboFinisherCooldownMs = 600;
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