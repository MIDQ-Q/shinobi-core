package com.example.shinobicore.combat;

public enum TaijutsuStyle {
    STANDARD("standard", 1.0f, 1.0f, 0.3f),
    STRONG_FIST("strong_fist", 1.6f, 1.3f, 0.5f);
    // GENTLE_FIST добавим с кланом Хьюга

    private final String id;
    private final float damageMult;
    private final float speedMult;
    private final float fatiguePerHit;

    TaijutsuStyle(String id, float damageMult, float speedMult, float fatiguePerHit) {
        this.id = id;
        this.damageMult = damageMult;
        this.speedMult = speedMult;
        this.fatiguePerHit = fatiguePerHit;
    }

    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }
    public float getSpeedMult() { return speedMult; }
    public float getFatiguePerHit() { return fatiguePerHit; }

    public static TaijutsuStyle fromId(String id) {
        for (TaijutsuStyle s : values()) {
            if (s.id.equals(id)) return s;
        }
        return STANDARD;
    }
}