package com.example.shinobicore.modules.visual.util;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public final class EffectRateLimiter {
    private static final Map<String, Long> lastEffectTime = new HashMap<>();
    private static long defaultCooldownMs = 100;
    private static int tickCounter = 0;

    public static void init(long cooldownMs) {
        defaultCooldownMs = cooldownMs;
    }

    public static boolean canPlayEffect(String effectId) {
        long now = System.currentTimeMillis();
        Long last = lastEffectTime.get(effectId);
        return last == null || (now - last) >= defaultCooldownMs;
    }

    public static void onEffectPlayed(String effectId) {
        lastEffectTime.put(effectId, System.currentTimeMillis());
    }

    // CRITICAL: Prevents memory leak (Forbidden Pattern #4)
    // Cleans up old entries every 5 seconds (100 ticks)
    public static void tick() {
        tickCounter++;
        if (tickCounter % 100 == 0) {
            long now = System.currentTimeMillis();
            long threshold = defaultCooldownMs * 10; // Keep data for 10x cooldown just in case
            Iterator<Map.Entry<String, Long>> it = lastEffectTime.entrySet().iterator();
            while (it.hasNext()) {
                Map.Entry<String, Long> entry = it.next();
                if (now - entry.getValue() > threshold) {
                    it.remove();
                }
            }
        }
    }
    
    public static void clear() {
        lastEffectTime.clear();
    }
}