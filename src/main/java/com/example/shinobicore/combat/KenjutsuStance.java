package com.example.shinobicore.combat;

/**
 * Combat Pack v1 (1.1.4): ДВЕ стойки катаны вместо трёх (решение дорожной карты:
 * «стойки упростить до двух — агрессивная и защитная»).
 *
 *   AGGRESSIVE — урон x1.15, скорость x1.15, точечное отклонение снарядов (tap),
 *                iaijutsu после паузы (перенесено из прежней стойки IAI).
 *   DEFENSIVE  — урон x0.85, скорость x1.0, КРУГОВОЙ щит при удержании (hold),
 *                блок ближнего боя (-60% урона) и парирование (окно 400 мс).
 *
 * Миграция: прежние id "seigan" и "iai" в сохранённых данных автоматически
 * маппятся fromId() — seigan -> DEFENSIVE, iai -> AGGRESSIVE. Ничего не теряется.
 */
public enum KenjutsuStance {
    AGGRESSIVE("aggressive", 1.15f, 1.15f, true, 1.0f),
    DEFENSIVE("defensive", 0.85f, 1.0f, true, 0.5f);

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
        if (id != null) {
            for (KenjutsuStance s : values()) {
                if (s.id.equals(id)) return s;
            }
            // миграция со старых сохранений
            if ("seigan".equals(id)) return DEFENSIVE;
            if ("iai".equals(id)) return AGGRESSIVE;
        }
        return AGGRESSIVE;
    }
}