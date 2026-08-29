package com.example.shinobicore.client.sensory;

import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;

/**
 * S6-01: Client-side sensory state.
 * Stores data received from server for rendering.
 */
public class SensoryClientState {

    // T1: Danger
    public static boolean dangerActive = false;

    // T2: Direction
    public static boolean directionActive = false;
    public static float directionX = 0f;
    public static float directionZ = 0f;

    // T3: Scan results
    public static List<ScanEntity> scanEntities = new ArrayList<>();
    public static long scanTimestamp = 0;
    public static final long SCAN_DURATION_MS = 3000; // 3 seconds

    // T4: Aura (handled by GLOWING effect, no extra client state needed)

    // T5: Chakra reading
    public static ReadingData lastReading = null;
    public static long readingTimestamp = 0;
    public static final long READING_DURATION_MS = 5000; // 5 seconds

    // Sensory tier (synced from server)
    public static int sensoryTier = 0;
    public static float scanCooldownRemaining = 0f;

    public static class ScanEntity {
        public final int entityId;
        public final double x, y, z;
        public final float height;
        public final boolean isHostile;

        public ScanEntity(int entityId, double x, double y, double z, float height, boolean isHostile) {
            this.entityId = entityId;
            this.x = x; this.y = y; this.z = z;
            this.height = height;
            this.isHostile = isHostile;
        }
    }

    public static class ReadingData {
        public final int entityId;
        public final String name;
        public final float chakraRatio;
        public final boolean chakraModeActive;
        public final int reserveLevel;
        public final boolean hasDojutsu;
        public final String dojutsuId;

        public ReadingData(int entityId, String name, float chakraRatio,
                          boolean chakraMode, int reserve, boolean dojutsu, String dojutsuId) {
            this.entityId = entityId;
            this.name = name;
            this.chakraRatio = chakraRatio;
            this.chakraModeActive = chakraMode;
            this.reserveLevel = reserve;
            this.hasDojutsu = dojutsu;
            this.dojutsuId = dojutsuId;
        }
    }

    public static boolean isScanActive() {
        return System.currentTimeMillis() - scanTimestamp < SCAN_DURATION_MS;
    }

    public static float getScanAlpha() {
        long elapsed = System.currentTimeMillis() - scanTimestamp;
        if (elapsed >= SCAN_DURATION_MS) return 0f;
        // Fade out in last 1 second
        if (elapsed > SCAN_DURATION_MS - 1000) {
            return 1f - (elapsed - (SCAN_DURATION_MS - 1000)) / 1000f;
        }
        return 1f;
    }

    public static boolean isReadingActive() {
        return lastReading != null && System.currentTimeMillis() - readingTimestamp < READING_DURATION_MS;
    }

    public static void clear() {
        dangerActive = false;
        directionActive = false;
        directionX = 0; directionZ = 0;
        scanEntities.clear();
        scanTimestamp = 0;
        lastReading = null;
        readingTimestamp = 0;
        sensoryTier = 0;
    }
}