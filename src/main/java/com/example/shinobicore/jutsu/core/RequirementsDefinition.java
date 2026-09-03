package com.example.shinobicore.jutsu.core;

import java.util.Map;

/**
 * Требования для изучения техники.
 */
public class RequirementsDefinition {
    private final int uses;
    private final int sp;
    private final Map<String, Integer> stats;
    private final Map<String, Integer> elements;
    private final String dojutsu;

    public RequirementsDefinition(int uses, int sp, Map<String, Integer> stats, Map<String, Integer> elements, String dojutsu) {
        this.uses = uses;
        this.sp = sp;
        this.stats = stats;
        this.elements = elements;
        this.dojutsu = dojutsu;
    }

    public int getUses() { return uses; }
    public int getSp() { return sp; }
    public Map<String, Integer> getStats() { return stats; }
    public Map<String, Integer> getElements() { return elements; }
    public String getDojutsu() { return dojutsu; }
}