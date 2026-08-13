package com.example.shinobicore.combat;

import net.minecraft.entity.LivingEntity;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public class MarkTracker {
    private static final Map<UUID, Long> MARKS = new ConcurrentHashMap<>();

    public static void mark(LivingEntity e, long ms) {
        MARKS.put(e.getUuid(), System.currentTimeMillis() + ms);
    }

    public static boolean isMarked(LivingEntity e) {
        Long t = MARKS.get(e.getUuid());
        if (t == null) return false;
        if (t <= System.currentTimeMillis()) {
            MARKS.remove(e.getUuid());
            return false;
        }
        return true;
    }

    public static float boost(LivingEntity e, float dmg) {
        return isMarked(e) ? dmg * 1.2f : dmg;
    }

    // cleanupExpired: call every 200 ticks from server tick handler
    public static void cleanupExpired() {
        long now = System.currentTimeMillis();
        MARKS.entrySet().removeIf(entry -> entry.getValue() <= now);
    }
}