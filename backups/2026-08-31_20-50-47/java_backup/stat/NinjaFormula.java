package com.example.shinobicore.stat;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.tree.TreePassives;

import java.util.Map;

public class NinjaFormula {
    private static ModConfig cfg() { return ModConfig.instance; }

    public static float maxChakra(NinjaPlayerData data) {
        return cfg().chakra.baseChakra
                + (data.getReserveLevel() - 1) * cfg().chakra.chakraPerReserveLevel
                + getClanReserveBonus(data.getClanId());
    }

    public static float regenPerSecond(NinjaPlayerData data) {
        float regen = cfg().chakra.baseRegen
                + data.getReserveLevel() * cfg().chakra.regenPerReserveLevel
                + data.getStatLevel(StatType.CONTROL) * cfg().chakra.regenPerControlLevel;
        if (data.getFatigue() > cfg().fatigue.hardThreshold)
            regen *= cfg().chakra.regenHardFatigueMultiplier;
        if (data.isExhausted())
            regen *= cfg().chakra.regenExhaustedMultiplier;
        return regen;
    }

    public static float fatigueDecayPerSecond(NinjaPlayerData data) {
        return cfg().fatigue.decayPerSecond;
    }

    public static float characterScore(JutsuDefinition def, NinjaPlayerData data) {
        Map<String, Float> weights = cfg().combat.categoryWeights.get(def.category());
        if (weights == null)
            weights = cfg().combat.categoryWeights.get("elemental_ninjutsu");
        float score = 0f;
        for (Map.Entry<String, Float> e : weights.entrySet()) {
            score += statValue(e.getKey(), def, data) * e.getValue();
        }
        return Math.max(0f, Math.min(100f, score));
    }

    private static float statValue(String key, JutsuDefinition def, NinjaPlayerData data) {
        if (key.equals("nature")) return def.hasNature() ? data.getNatureLevel(def.nature()) : 0;
        if (key.equals("reserve")) return data.getReserveLevel();
        for (StatType s : StatType.values()) {
            if (s.getId().equals(key)) return data.getStatLevel(s);
        }
        return 0f;
    }

    public static float usageScore(JutsuDefinition def, NinjaPlayerData data) {
        int uses = data.getJutsuUsage(def.id());
        float req = Math.max(1, def.requiredUsesForFullProficiency());
        return Math.min(100f, uses * 100f / req);
    }

    public static float mastery(JutsuDefinition def, NinjaPlayerData data) {
        float m = usageScore(def, data) * cfg().combat.masteryUsageWeight
                + characterScore(def, data) * cfg().combat.masteryStatWeight;
        return Math.max(0f, Math.min(100f, m));
    }

    public static float calculateCost(JutsuDefinition def, NinjaPlayerData data) {
        float cost = def.baseCost();
        float m = mastery(def, data) / 100f;
        float controlRed = data.getStatLevel(StatType.CONTROL) / 100f * cfg().combat.costControlReductionMax;
        float natureRed = 0f;
        if (def.hasNature()) {
            natureRed = data.getNatureLevel(def.nature()) / 100f * cfg().combat.costNatureReductionMax;
            if (data.getAffinity() == def.nature()) {
                cost *= cfg().combat.affinityCostMultiplier;
            }
        }
        float masteryRed = m * cfg().combat.costMasteryReductionMax;
        float totalRed = Math.min(0.8f, controlRed + natureRed + masteryRed);
        cost *= (1f - totalRed);

        // === НОВОЕ: costMultiplier клана ===
        ClanDefinition clan = ClanRegistry.get(data.getClanId());
        if (clan != null && def.hasNature()) {
            Float mult = clan.costMultiplier().get(def.nature().getId());
            if (mult != null) {
                cost *= mult;
            }
        }

        float soft = cfg().fatigue.softThreshold;
        if (data.getFatigue() > soft) {
            float over = (data.getFatigue() - soft) / (100f - soft);
            cost *= 1f + over * cfg().fatigue.costPenaltyMax;
        }
        return Math.max(1f, cost);
    }

    public static float damageMultiplier(NinjaPlayerData data, JutsuDefinition def) {
        float m = mastery(def, data) / 100f;
        float mult = cfg().combat.damageBaseMultiplier + m * cfg().combat.damageMasteryScale;
        if (def.hasNature() && data.getAffinity() == def.nature()) {
            mult *= cfg().combat.affinityDamageMultiplier;
        }
        return mult;
    }

    public static boolean checkRequirements(JutsuDefinition def, NinjaPlayerData data) {
        for (Map.Entry<String, Integer> req : def.requirements().entrySet()) {
            String key = req.getKey();
            int required = req.getValue();
            if (key.equals("control")) {
                if (data.getStatLevel(StatType.CONTROL) < required) return false;
            } else if (key.equals("ninjutsu")) {
                if (data.getStatLevel(StatType.NINJUTSU) < required) return false;
            } else if (key.startsWith("nature_")) {
                String natureId = key.substring(7);
                for (ElementType e : ElementType.values()) {
                    if (e.getId().equals(natureId)) {
                        if (data.getNatureLevel(e) < required) return false;
                        break;
                    }
                }
            }
        }
        return true;
    }

    public static float meditationRegenMultiplier() { return cfg().meditation.regenMultiplier; }
    public static float meditationFatigueDecayMultiplier() { return cfg().meditation.fatigueDecayMultiplier; }
    public static int meditationReserveXpPerSecond() { return cfg().meditation.reserveXpPerSecond; }
    public static int meditationControlXpPerSecond() { return cfg().meditation.controlXpPerSecond; }

    public static int xpToNextLevel(int level) {
        return cfg().progression.xpBase
                + level * cfg().progression.xpPerLevel
                + level * level * cfg().progression.xpSquared;
    }

    public static int spCostForLevel(int level) {
        return cfg().progression.spBaseCost + (level / 10) * cfg().progression.spExtraCostEvery10;
    }

    public static int maxHealth(int hpLevel) {
        return 20 + hpLevel * 20;
    }

    public static float speedMultiplier(int speedLevel, boolean chakraMode) {
        float base = 1.0f + speedLevel * 0.125f;
        if (chakraMode) base *= 2.0f;
        return Math.min(base, chakraMode ? 4.0f : 2.0f);
    }

    public static float jumpMultiplier(int jumpLevel, boolean chakraMode) {
        float base = 1.0f + jumpLevel * 0.125f;
        if (chakraMode) base *= 2.0f;
        return Math.min(base, chakraMode ? 4.0f : 2.0f);
    }

    public static float jumpHorizontalMultiplier(int jumpLevel, boolean chakraMode) {
        if (!chakraMode) return 1.0f + jumpLevel * 0.125f;
        return 2.0f + jumpLevel * 0.5f;
    }

    public static float jumpVerticalMultiplier(int jumpLevel, boolean chakraMode) {
        if (!chakraMode) return 1.0f;
        return 1.5f + jumpLevel * 0.15f;
    }

    public static int bodySpCost() {
        return cfg().progression.spBaseCost * 2;
    }

    public static float chakraModeDrainPerSecond(NinjaPlayerData data) {
        float controlReduction = data.getStatLevel(StatType.CONTROL) / 100f * 0.9f;
        return 2.0f * (1.0f - controlReduction);
    }

    public static float chakraModeRegenMultiplier() {
        return 0.2f;
    }

    public static boolean addStatXp(NinjaPlayerData data, StatType stat, int amount) {
        int startLevel = data.getStatLevel(stat);
        int currentXp = data.getStatXp(stat) + amount;
        int level = startLevel;
        boolean leveled = false;
        while (level < NinjaPlayerData.MAX_LEVEL && currentXp >= xpToNextLevel(level)) {
            currentXp -= xpToNextLevel(level);
            level++;
            leveled = true;
        }
        data.setStatLevel(stat, level);
        data.setStatXp(stat, currentXp);
        if (leveled) {
            data.addSkillPoints((level - startLevel) * cfg().progression.spPerLevelUp);
        }
        return leveled;
    }

    public static boolean addReserveXp(NinjaPlayerData data, int amount) {
        int startLevel = data.getReserveLevel();
        int currentXp = data.getReserveXp() + amount;
        int level = startLevel;
        boolean leveled = false;
        while (level < NinjaPlayerData.MAX_LEVEL && currentXp >= xpToNextLevel(level)) {
            currentXp -= xpToNextLevel(level);
            level++;
            leveled = true;
        }
        data.setReserveLevel(level);
        data.setReserveXp(currentXp);
        if (leveled) {
            data.addSkillPoints((level - startLevel) * cfg().progression.spPerLevelUp);
        }
        return leveled;
    }

    public static boolean addNatureXp(NinjaPlayerData data, ElementType element, int amount) {
        int startLevel = data.getNatureLevel(element);
        int currentXp = data.getNatureXp(element) + amount;
        int level = startLevel;
        boolean leveled = false;
        while (level < NinjaPlayerData.MAX_LEVEL && currentXp >= xpToNextLevel(level)) {
            currentXp -= xpToNextLevel(level);
            level++;
            leveled = true;
        }
        data.setNatureLevel(element, level);
        data.setNatureXp(element, currentXp);
        if (leveled) {
            data.addSkillPoints((level - startLevel) * cfg().progression.spPerLevelUp);
        }
        return leveled;
    }

    public static boolean grantStatXp(NinjaPlayerData data, StatType stat, int amount) {
        if (!data.tryConsumeXpBudget("stat_" + stat.getId(), amount, cfg().progression.maxXpPerMinute)) return false;
        return addStatXp(data, stat, amount);
    }

    public static boolean grantNatureXp(NinjaPlayerData data, ElementType element, int amount) {
        if (!data.tryConsumeXpBudget("nature_" + element.getId(), amount, cfg().progression.maxXpPerMinute)) return false;
        return addNatureXp(data, element, amount);
    }

    public static boolean grantReserveXp(NinjaPlayerData data, int amount) {
        if (!data.tryConsumeXpBudget("reserve", amount, cfg().progression.maxXpPerMinute)) return false;
        return addReserveXp(data, amount);
    }

    public static boolean grantUsage(NinjaPlayerData data, String jutsuId, int amount) {
        if (!data.tryConsumeXpBudget("usage_" + jutsuId, amount, cfg().progression.maxUsagePerMinute)) return false;
        data.addJutsuUsage(jutsuId, amount);
        return true;
    }

    private static float getClanReserveBonus(String clanId) {
        if (clanId == null || clanId.equals("none")) return 0f;
        ClanDefinition clan = ClanRegistry.get(clanId);
        if (clan == null) return 0f;
        return clan.reserveBonus();
    }
}