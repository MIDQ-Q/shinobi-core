package com.example.shinobicore.combat;

/**
 * ADR-002: делегат ComboMachine. Публичный API сохранён, чтобы не трогать
 * ~10 мест вызова; копии таблиц множителей удалены (были продублированы
 * в KenjutsuFormulas.STEP_MULT / STEP_KB).
 */
public class TaijutsuCombo {
    public static final int MAX_STEPS = ComboMachine.MAX_STEPS;
    public static final long COMBO_TIMEOUT_MS = ComboMachine.TIMEOUT_BASE_MS;

    public static float getDamageMult(int step) { return ComboMachine.damageMult(step); }

    public static float getKnockback(int step)  { return ComboMachine.knockback(step); }

    public static boolean isFinisher(int step)  { return ComboMachine.isFinisher(step); }
}