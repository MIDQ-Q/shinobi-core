package com.example.shinobicore.entity.enemy;

/**
 * Enemy ranks with HP, damage and allowed jutsu pools.
 * HLD: Section 5 (enemies reuse standard JutsuDefinition JSON)
 */
public enum NinjaRank {

    ACADEMY("academy", 20.0f, 3.0f, new String[0]),
    GENIN("genin", 40.0f, 5.0f, new String[] { "shinobicore:fireball" }),
    CHUNIN("chunin", 60.0f, 7.0f, new String[] {
        "shinobicore:fireball", "shinobicore:fire_phoenix"
    }),
    JONIN("jonin", 90.0f, 10.0f, new String[] {
        "shinobicore:fireball", "shinobicore:fire_phoenix",
        "shinobicore:fire_dragon", "shinobicore:aoe_explosion"
    });

    private final String id;
    private final float maxHp;
    private final float meleeDamage;
    private final String[] jutsus;

    NinjaRank(String id, float maxHp, float meleeDamage, String[] jutsus) {
        this.id = id;
        this.maxHp = maxHp;
        this.meleeDamage = meleeDamage;
        this.jutsus = jutsus;
    }

    public String getId() { return id; }
    public float getMaxHp() { return maxHp; }
    public float getMeleeDamage() { return meleeDamage; }
    public String[] getJutsus() { return jutsus; }

    public static NinjaRank fromId(String id) {
        if (id == null) return GENIN;
        for (NinjaRank r : values()) {
            if (r.id.equals(id)) return r;
        }
        return GENIN;
    }
}