package com.example.shinobicore.combat;

/**
 * Единый источник правды для шагов комбо (ADR-002).
 *
 * Заменяет две независимые копии таблиц, которые были в:
 *   - TaijutsuCombo.STEP_DAMAGE / STEP_KNOCKBACK
 *   - KenjutsuFormulas.STEP_MULT / STEP_KB
 *
 * Намеренно БЕЗ импортов Minecraft: класс общий для клиента и сервера,
 * и его можно покрыть юнит-тестами (см. 05_ТЕСТ_ПЛАН.md, T-A-2).
 *
 * Таблицы STEP_HITSTOP_* / STEP_SHAKE добавлены заранее под Спринт 8
 * ("ощущение удара"): сейчас хитстоп жёстко равен 80/160 мс для всех шагов,
 * из-за чего финишер не отличается от тычка.
 */
public final class ComboMachine {

    private ComboMachine() {}

    /** Количество шагов в комбо (0..3, шаг 3 — финишер). */
    public static final int MAX_STEPS = 4;

    /** Базовое окно комбо в мс; умножается на (1 + bonus) из древа навыков. */
    public static final long TIMEOUT_BASE_MS = 1500L;

    /**
     * Допуск рассинхрона часов клиент/сервер при проверке кулдауна.
     * Клиент стреляет на эту величину раньше серверного порога.
     */
    public static final long CLOCK_TOLERANCE_MS = 60L;

    private static final float[] STEP_DAMAGE_MULT = { 1.00f, 1.00f, 1.20f, 1.80f };
    private static final float[] STEP_KNOCKBACK   = { 0.30f, 0.30f, 0.40f, 1.20f };
    private static final int[]   STEP_HITSTOP_ATK = {   60,     60,    90,   160  };
    private static final int[]   STEP_HITSTOP_TGT = {  100,    100,   140,   260  };
    private static final float[] STEP_SHAKE       = { 0.03f,  0.03f, 0.06f, 0.12f };

    /**
     * Причина, по которой сервер принял или отклонил пакет атаки.
     * Передаётся клиенту вместе с COMBO_SYNC, чтобы клиент знал,
     * какой визуальный отклик играть.
     *
     * WHIFF — не отказ: удар выполнен, но никого не задел.
     * По решению D-2 комбо от промаха НЕ растёт, но окно комбо НЕ сбрасывается.
     */
    public enum RejectReason {
        OK((byte) 0),
        COOLDOWN((byte) 1),
        EXHAUSTED((byte) 2),
        BLOCKING((byte) 3),
        DESYNC((byte) 4),
        WHIFF((byte) 5);

        private final byte code;

        RejectReason(byte code) { this.code = code; }

        public byte code() { return code; }

        public static RejectReason fromCode(byte c) {
            for (RejectReason r : values()) {
                if (r.code == c) return r;
            }
            return DESYNC;
        }
    }

    public static int clampStep(int step) {
        if (step < 0) return 0;
        if (step >= MAX_STEPS) return MAX_STEPS - 1;
        return step;
    }

    public static float damageMult(int step) { return STEP_DAMAGE_MULT[clampStep(step)]; }

    public static float knockback(int step)  { return STEP_KNOCKBACK[clampStep(step)]; }

    /** Длительность стоп-кадра для АТАКУЮЩЕГО (Спринт 8). */
    public static int hitStopAttackerMs(int step) { return STEP_HITSTOP_ATK[clampStep(step)]; }

    /** Длительность стоп-кадра для ЦЕЛИ (Спринт 8). */
    public static int hitStopTargetMs(int step)   { return STEP_HITSTOP_TGT[clampStep(step)]; }

    /** Амплитуда тряски камеры (Спринт 8). */
    public static float shake(int step) { return STEP_SHAKE[clampStep(step)]; }

    public static boolean isFinisher(int step) { return clampStep(step) == MAX_STEPS - 1; }

    /** Окно комбо с учётом бонуса древа навыков (tai_combo_plus = +0.5). */
    public static long timeoutMs(float bonusFraction) {
        float b = bonusFraction;
        if (Float.isNaN(b) || b < 0f) b = 0f;
        return (long) (TIMEOUT_BASE_MS * (1.0f + b));
    }

    public static int nextStep(int step) { return (clampStep(step) + 1) % MAX_STEPS; }
}