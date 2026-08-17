package com.example.shinobicore.sensory;

/**
 * S6-01: Sensory perception tiers.
 * Each tier unlocks a new sensory capability.
 * Tiers are determined by unlocked tree nodes.
 */
public enum SensoryTier {
    NONE(0, 0, 0f, 0f),
    T1_DANGER(1, 16, 0f, 0f),
    T2_DIRECTION(2, 24, 0f, 0f),
    T3_SCAN(3, 32, 60f, 8f),
    T4_AURA(4, 40, 0f, 12f),
    T5_READING(5, 48, 100f, 20f);

    private final int level;
    private final int radius;
    private final float scanCooldownSeconds;
    private final float chakraCostPerUse;

    SensoryTier(int level, int radius, float scanCooldown, float chakraCost) {
        this.level = level;
        this.radius = radius;
        this.scanCooldownSeconds = scanCooldown;
        this.chakraCostPerUse = chakraCost;
    }

    public int getLevel() { return level; }
    public int getRadius() { return radius; }
    public float getScanCooldownSeconds() { return scanCooldownSeconds; }
    public float getChakraCostPerUse() { return chakraCostPerUse; }

    public static SensoryTier fromLevel(int level) {
        for (SensoryTier t : values()) {
            if (t.level == level) return t;
        }
        return NONE;
    }

    public boolean isAtLeast(SensoryTier other) {
        return this.level >= other.level;
    }
}