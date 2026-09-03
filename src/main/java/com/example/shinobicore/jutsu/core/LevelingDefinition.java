package com.example.shinobicore.jutsu.core;

import java.util.Map;

/**
 * Определение прокачки техники (1-15 уровней).
 */
public class LevelingDefinition {
    private final int maxLevel;
    private final Map<Integer, LevelData> levels;

    public LevelingDefinition(int maxLevel, Map<Integer, LevelData> levels) {
        this.maxLevel = maxLevel;
        this.levels = levels;
    }

    public int getMaxLevel() { return maxLevel; }
    public Map<Integer, LevelData> getLevels() { return levels; }

    public LevelData getLevelData(int level) {
        return levels.get(level);
    }

    public static class LevelData {
        private final Map<String, Double> numericParams;
        private final Map<String, Integer> requirements;

        public LevelData(Map<String, Double> numericParams, Map<String, Integer> requirements) {
            this.numericParams = numericParams;
            this.requirements = requirements;
        }

        public Map<String, Double> getNumericParams() { return numericParams; }
        public Map<String, Integer> getRequirements() { return requirements; }
    }
}