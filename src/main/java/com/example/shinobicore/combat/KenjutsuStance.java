package com.example.shinobicore.combat;
public enum KenjutsuStance {
    AGGRESSIVE("aggressive", 1.15f, 1.15f, true, 1.0f),
    SEIGAN("seigan", 0.85f, 1.0f, true, 0.5f),
    IAI("iai", 1.0f, 0.9f, false, 1.0f);
    private final String id;
    private final float damageMult;
    private final float speedMult;
    private final boolean canDeflect;
    private final float shieldSlow;
    KenjutsuStance(String id, float damageMult, float speedMult, boolean canDeflect, float shieldSlow) {
        this.id = id; this.damageMult = damageMult; this.speedMult = speedMult;
        this.canDeflect = canDeflect; this.shieldSlow = shieldSlow;
    }
    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }
    public float getSpeedMult() { return speedMult; }
    public boolean canDeflect() { return canDeflect; }
    public float getShieldSlow() { return shieldSlow; }
    public static KenjutsuStance fromId(String id) {
        for (KenjutsuStance s : values()) if (s.id.equals(id)) return s;
        return AGGRESSIVE;
    }
}