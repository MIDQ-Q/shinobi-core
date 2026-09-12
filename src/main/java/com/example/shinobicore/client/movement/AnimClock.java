package com.example.shinobicore.client.movement;

import com.example.shinobicore.client.combat.frenzy.FrenzyClientState;

/**
 * Combat Pack v1 (1.1.4): масштабируемые часы для анимаций.
 *
 * В боевом раже (FrenzyClientState) визуальное время замедляется — это
 * КЛИЕНТСКИЙ эффект: серверный тикрейт не меняется, мультиплеер не ломается
 * (см. план Movement/Combat: «игрок ВИДИТ замедление, игра не ломается»).
 *
 * Время накапливается по реальным наносекундам между обращениями, поэтому
 * несколько вызовов за кадр (разные сущности в рендере) не «ускоряют» часы:
 * каждый вызов добавляет только реально прошедший отрезок.
 */
public final class AnimClock {

    private AnimClock() {}

    private static long scaledMs = System.currentTimeMillis();
    private static long lastRealNanos = System.nanoTime();

    /** Текущее «визуальное» время в миллисекундах (замедляется в раже). */
    public static long scaledNow() {
        long realNow = System.nanoTime();
        double dtMs = (realNow - lastRealNanos) / 1.0e6;
        lastRealNanos = realNow;
        if (dtMs < 0 || dtMs > 500) dtMs = 50;   // защита от скачков/слипа окна
        float scale = FrenzyClientState.getTimeScale();
        scaledMs += (long) (dtMs * scale);
        return scaledMs;
    }

    /** Сброс при входе/выходе из мира. */
    public static void reset() {
        scaledMs = System.currentTimeMillis();
        lastRealNanos = System.nanoTime();
    }
}