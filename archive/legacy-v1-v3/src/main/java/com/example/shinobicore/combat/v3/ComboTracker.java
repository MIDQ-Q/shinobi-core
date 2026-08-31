// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 14 combo tracker foundation.
 */
public final class ComboTracker {
    private static final Map<UUID, ComboState> COMBOS = new ConcurrentHashMap<>();

    private ComboTracker() {}

    public static class ComboState {
        public int step = 0;
        public long lastHitMs = 0;
    }

    public static ComboState get(UUID uuid) {
        return COMBOS.computeIfAbsent(uuid, id -> new ComboState());
    }

    public static void registerHit(UUID uuid, long nowMs, int comboWindowMs) {
        ComboState state = get(uuid);

        if (nowMs - state.lastHitMs <= comboWindowMs) {
            state.step++;
        } else {
            state.step = 1;
        }

        state.lastHitMs = nowMs;
    }

    public static int getStep(UUID uuid) {
        return get(uuid).step;
    }

    public static void reset(UUID uuid) {
        COMBOS.remove(uuid);
    }

    public static void resetAll() {
        COMBOS.clear();
    }
}