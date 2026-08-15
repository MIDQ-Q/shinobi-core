package com.example.shinobicore.combat;

/**
 * Kenjutsu stances with extended parameters.
 * AGGRESSIVE: fast + strong, high fatigue.
 * SEIGAN: defensive, parry/deflect, chakra generation.
 * IAI: slow but devastating first strike.
 */
public enum KenjutsuStance {
    AGGRESSIVE("aggressive", 1.15f, 1.25f, true, 1.0f, 1.4f, 1.3f, 0f),
    SEIGAN("seigan", 0.85f, 1.0f, true, 0.5f, 0.8f, 1.0f, 0.5f),
    IAI("iai", 1.0f, 0.85f, false, 1.0f, 1.0f, 1.5f, 0f);

    private final String id;
    private final float damageMult;
    private final float speedMult;
    private final boolean canDeflect;
    private final float shieldSlow;
    private final float fatigueMult;
    private final float chakraDamageMult;
    private final float parryChakraGain;

    KenjutsuStance(String id, float damageMult, float speedMult, boolean canDeflect,
                   float shieldSlow, float fatigueMult, float chakraDamageMult, float parryChakraGain) {
        this.id = id;
        this.damageMult = damageMult;
        this.speedMult = speedMult;
        this.canDeflect = canDeflect;
        this.shieldSlow = shieldSlow;
        this.fatigueMult = fatigueMult;
        this.chakraDamageMult = chakraDamageMult;
        this.parryChakraGain = parryChakraGain;
    }

    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }
    public float getSpeedMult() { return speedMult; }
    public boolean canDeflect() { return canDeflect; }
    public float getShieldSlow() { return shieldSlow; }
    public float getFatigueMult() { return fatigueMult; }
    public float getChakraDamageMult() { return chakraDamageMult; }
    public float getParryChakraGain() { return parryChakraGain; }

    public static KenjutsuStance fromId(String id) {
        for (KenjutsuStance s : values()) if (s.id.equals(id)) return s;
        return AGGRESSIVE;
    }
}