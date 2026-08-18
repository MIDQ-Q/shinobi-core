package com.example.shinobicore.entity.enemy;

/**
 * S9-07: Enemy rank presets.
 * Each rank defines base stats, attack count, kawarimi chance, telegraph time.
 */
public enum NinjaRank {
    GENIN("genin", 20.0f, 200.0f, 100.0f, 0.25f, 4.0f, 0.3f, 1, 0.0f, 30, false),
    CHUNIN("chunin", 30.0f, 400.0f, 200.0f, 0.28f, 6.0f, 0.5f, 2, 0.10f, 24, false),
    JONIN("jonin", 40.0f, 800.0f, 400.0f, 0.32f, 9.0f, 0.7f, 3, 0.25f, 16, false),
    ANBU("anbu", 50.0f, 1200.0f, 600.0f, 0.35f, 12.0f, 0.9f, 4, 0.40f, 10, false),
    NUKE_NIN("nuke_nin", 80.0f, 2000.0f, 1000.0f, 0.35f, 16.0f, 1.0f, 4, 0.50f, 10, true);

    private final String id;
    private final float maxHealth;
    private final float maxChakra;
    private final float maxStamina;
    private final float moveSpeed;
    private final float baseDamage;
    private final float aggression;
    private final int attackCount;
    private final float kawarimiChance;
    private final int telegraphTicks;
    private final boolean isBossRank;

    NinjaRank(String id, float maxHealth, float maxChakra, float maxStamina,
              float moveSpeed, float baseDamage, float aggression, int attackCount,
              float kawarimiChance, int telegraphTicks, boolean isBossRank) {
        this.id = id;
        this.maxHealth = maxHealth;
        this.maxChakra = maxChakra;
        this.maxStamina = maxStamina;
        this.moveSpeed = moveSpeed;
        this.baseDamage = baseDamage;
        this.aggression = aggression;
        this.attackCount = attackCount;
        this.kawarimiChance = kawarimiChance;
        this.telegraphTicks = telegraphTicks;
        this.isBossRank = isBossRank;
    }

    public String getId() { return id; }
    public float getMaxHealth() { return maxHealth; }
    public float getMaxChakra() { return maxChakra; }
    public float getMaxStamina() { return maxStamina; }
    public float getMoveSpeed() { return moveSpeed; }
    public float getBaseDamage() { return baseDamage; }
    public float getAggression() { return aggression; }
    public int getAttackCount() { return attackCount; }
    public float getKawarimiChance() { return kawarimiChance; }
    public int getTelegraphTicks() { return telegraphTicks; }
    public boolean isBossRank() { return isBossRank; }

    public static NinjaRank fromId(String id) {
        for (NinjaRank r : values()) {
            if (r.id.equals(id)) return r;
        }
        return GENIN;
    }
}