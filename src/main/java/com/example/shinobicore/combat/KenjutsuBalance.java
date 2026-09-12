package com.example.shinobicore.combat;

/**
 * Единый источник таймингов катаны для КЛИЕНТА и СЕРВЕРА (задача D4).
 *
 * До этого кулдаун был продублирован и не совпадал:
 *   клиент (KenjutsuClientHandler):  aggressive 350 / seigan 450 / iai 500 мс
 *   сервер (KenjutsuFormulas):       max(200, 450 / speedMult) = 391 / 450 / 500 мс
 *                                    с допуском "-50 мс" -> порог 341 / 400 / 450 мс
 * Запас у aggressive составлял 9 мс: любая сетевая задержка или просадка FPS
 * приводила к молчаливому отклонению удара.
 *
 * Намеренно БЕЗ серверных импортов (KenjutsuStance их тоже не имеет),
 * поэтому класс безопасно вызывать из клиентского кода.
 */
public final class KenjutsuBalance {

    private KenjutsuBalance() {}

    /** Насколько раньше серверного порога клиенту разрешено отправлять удар. */
    public static final long SAFETY_MARGIN_MS = 60L;

    /** Базовый кулдаун до деления на множитель скорости стойки. */
    public static final double BASE_COOLDOWN_MS = 450.0;

    /** Минимально возможный кулдаун. */
    public static final long MIN_COOLDOWN_MS = 200L;

    /**
     * Iaijutsu: первый удар после паузы бьёт сильнее.
     * Механика перенесена из удалённой стойки IAI в aggressive (решение Q-A / D-3).
     */
    public static final long  IAIJUTSU_IDLE_MS    = 2000L;
    public static final float IAIJUTSU_MULTIPLIER = 2.2f;

    /** Серверный порог: раньше этого момента удар отклоняется. */
    public static long serverCooldownMs(KenjutsuStance stance) {
        if (stance == null) stance = KenjutsuStance.AGGRESSIVE;
        float speed = stance.getSpeedMult();
        if (speed <= 0f) speed = 1f;
        return Math.max(MIN_COOLDOWN_MS, (long) (BASE_COOLDOWN_MS / speed));
    }

    /** Клиентский кулдаун: всегда строго меньше серверного порога. */
    public static long clientCooldownMs(KenjutsuStance stance) {
        return Math.max(150L, serverCooldownMs(stance) - SAFETY_MARGIN_MS);
    }

    /** Серверный допуск (то, с чем сравнивается в обработчике пакета). */
    public static long serverAcceptAfterMs(KenjutsuStance stance) {
        return Math.max(100L, serverCooldownMs(stance) - CLOCK_TOLERANCE_MS());
    }

    private static long CLOCK_TOLERANCE_MS() { return ComboMachine.CLOCK_TOLERANCE_MS; }
}