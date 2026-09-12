package com.example.shinobicore.config;

/**
 * C4: точка доступа к боевой секции конфига.
 *
 * До этого ConfigManager.getSection(...) не вызывался НИ РАЗУ во всём проекте,
 * из-за чего все поля CombatConfigSection были фантомными: игрок менял
 * parryWindowMs в файле, а в игре ничего не происходило.
 *
 * Использование в Спринте 7:
 *   long window = (long) CombatCfg.get().parryWindowMs;
 */
public final class CombatCfg {

    private CombatCfg() {}

    /** Запасной экземпляр с дефолтами — если секция ещё не зарегистрирована. */
    private static final CombatConfigSection FALLBACK = new CombatConfigSection();

    public static CombatConfigSection get() {
        CombatConfigSection s = ConfigManager.getSection(CombatConfigSection.class);
        return s != null ? s : FALLBACK;
    }

    public static long parryWindowMs() {
        float v = get().parryWindowMs;
        return (long) (Float.isNaN(v) ? 400.0f : v);
    }

    public static long parryCooldownMs() {
        float v = get().parryCooldownMs;
        return (long) (Float.isNaN(v) ? 200.0f : v);
    }

    public static float blockDamageReduction() {
        float v = get().blockBaseDamageReduction;
        if (Float.isNaN(v)) return 0.6f;
        return Math.min(0.95f, Math.max(0.0f, v));
    }

    public static float blockStaminaPerSecond() {
        float v = get().blockStaminaPerSecond;
        if (Float.isNaN(v) || v < 0f) return 3.0f;
        return v;
    }
}