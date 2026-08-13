package com.example.shinobicore.client;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
public class HandSignsClientState {
    public static class ActiveSigns {
        public final String jutsuId;
        public final long startTimeMs;
        public final int durationTicks;
        public ActiveSigns(String jutsuId, int durationTicks) {
            this.jutsuId = jutsuId;
            this.startTimeMs = System.currentTimeMillis();
            this.durationTicks = durationTicks;
        }
        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTimeMs;
            return Math.min(1f, (float) elapsed / (durationTicks * 50L));
        }
        public boolean isExpired() {
            return System.currentTimeMillis() - startTimeMs > (durationTicks * 50L) + 500;
        }
    }
    private static final Map<Integer, ActiveSigns> CASTING = new ConcurrentHashMap<>();
    public static void startCasting(int entityId, String jutsuId, int durationTicks) {
        CASTING.put(entityId, new ActiveSigns(jutsuId, durationTicks));
    }
    public static void interruptCasting(int entityId) {
        CASTING.remove(entityId);
    }
    public static ActiveSigns get(int entityId) {
        ActiveSigns a = CASTING.get(entityId);
        if (a != null && a.isExpired()) { CASTING.remove(entityId); return null; }
        return a;
    }
    public static boolean isCasting(int entityId) { return get(entityId) != null; }
    public static void clear() { CASTING.clear(); }
}