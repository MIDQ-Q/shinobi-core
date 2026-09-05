package com.example.shinobicore.jutsu.core;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

public class LevelingDefinition {
    private final int maxLevel;
    private final TreeMap<Integer, LevelData> levels;

    public LevelingDefinition(int maxLevel, Map<Integer, LevelData> levels) {
        this.maxLevel = maxLevel;
        this.levels = new TreeMap<>(levels);
    }

    public int getMaxLevel() { return maxLevel; }
    public Map<Integer, LevelData> getLevels() { return levels; }

    /** Step logic: value at level L = value of nearest specified row <= L. */
    public Map<String, Double> numericAt(int level) {
        Map<String, Double> r = new HashMap<>();
        for (Map.Entry<Integer, LevelData> e : levels.entrySet()) {
            if (e.getKey() <= level) r.putAll(e.getValue().getNumericParams());
        }
        return r;
    }

    public List<String> unlockedPropertiesAt(int level) {
        List<String> r = new ArrayList<>();
        for (Map.Entry<Integer, LevelData> e : levels.entrySet()) {
            if (e.getKey() <= level) r.addAll(e.getValue().getUnlockProperties());
        }
        return r;
    }

    public List<EffectDefinition> unlockedEffectsAt(int level) {
        List<EffectDefinition> r = new ArrayList<>();
        for (Map.Entry<Integer, LevelData> e : levels.entrySet()) {
            if (e.getKey() <= level) r.addAll(e.getValue().getUnlockEffects());
        }
        return r;
    }

    public Integer nextRowLevel(int level) {
        for (Integer k : levels.keySet()) if (k > level) return k;
        return null;
    }

    public LevelData rowAt(int levelKey) { return levels.get(levelKey); }

    public double firstTableDamage() {
        for (Map.Entry<Integer, LevelData> e : levels.entrySet()) {
            Double d = e.getValue().getNumericParams().get("damage");
            if (d != null) return d;
        }
        return -1;
    }

    public static class LevelData {
        private final Map<String, Double> numericParams;
        private final Map<String, Integer> requirements;
        private final List<String> unlockProperties;
        private final List<EffectDefinition> unlockEffects;

        public LevelData(Map<String, Double> numericParams, Map<String, Integer> requirements,
                         List<String> unlockProperties, List<EffectDefinition> unlockEffects) {
            this.numericParams = numericParams;
            this.requirements = requirements;
            this.unlockProperties = unlockProperties;
            this.unlockEffects = unlockEffects;
        }

        public Map<String, Double> getNumericParams() { return numericParams; }
        public Map<String, Integer> getRequirements() { return requirements; }
        public List<String> getUnlockProperties() { return unlockProperties; }
        public List<EffectDefinition> getUnlockEffects() { return unlockEffects; }
    }
}