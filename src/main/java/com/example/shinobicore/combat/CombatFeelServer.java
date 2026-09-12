package com.example.shinobicore.combat;

import com.example.shinobicore.config.ModConfig;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Combat Pack v1 (1.1.4): серверный учёт таймингов блока/парирования.
 *
 * Клиент шлёт KATANA_DEFLECT (held=true/false) — здесь фиксируется момент
 * НАЖАТИЯ. KatanaDeflectMixin сравнивает возраст нажатия с окном парирования
 * (combat.parryWindowMs, дефолт 400 мс): попал в окно — PARRY (урон отменён,
 * атакующий отброшен), не попал, но держит блок в защитной стойке — урон
 * режется на combat.blockReduction.
 */
public final class CombatFeelServer {

    private static final Map<UUID, Long> DEFLECT_PRESS = new ConcurrentHashMap<>();
    private static final long EXPIRY_MS = 5000L;

    private CombatFeelServer() {}

    public static void onDeflectToggle(UUID uid, boolean held) {
        if (uid == null) return;
        if (held) {
            DEFLECT_PRESS.put(uid, System.currentTimeMillis());
        } else {
            DEFLECT_PRESS.remove(uid);
        }
    }

    /** Момент нажатия блока или -1, если не нажат/протух. */
    public static long getDeflectPressMs(UUID uid) {
        if (uid == null) return -1L;
        Long t = DEFLECT_PRESS.get(uid);
        if (t == null) return -1L;
        if (System.currentTimeMillis() - t > EXPIRY_MS) {
            DEFLECT_PRESS.remove(uid);
            return -1L;
        }
        return t;
    }

    public static long parryWindowMs() {
        ModConfig.Combat c = ModConfig.instance.combat;
        return (c != null && c.parryWindowMs > 0) ? c.parryWindowMs : 400L;
    }

    public static float blockReduction() {
        ModConfig.Combat c = ModConfig.instance.combat;
        if (c == null) return 0.6f;
        return Math.max(0f, Math.min(0.95f, c.blockReduction));
    }

    public static float blockFatigue() {
        ModConfig.Combat c = ModConfig.instance.combat;
        return (c != null && c.blockFatigue >= 0) ? c.blockFatigue : 2.5f;
    }

    public static float parryKnockback() {
        ModConfig.Combat c = ModConfig.instance.combat;
        return (c != null && c.parryKnockback > 0) ? c.parryKnockback : 0.9f;
    }

    public static void removePlayer(UUID uid) {
        if (uid != null) DEFLECT_PRESS.remove(uid);
    }
}