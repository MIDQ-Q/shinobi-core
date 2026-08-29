package com.example.shinobicore.client.debug;

/**
 * S0-08: Debug profiler for developer overlay.
 * Collects metrics: VFX count, clones, packets/s, render time, memory.
 */
public class DebugProfiler {
    private static volatile boolean enabled = false;
    private static int activeVfxCount = 0;
    private static int activeCloneCount = 0;
    private static long lastFrameNs = 0;
    private static long frameTimeNs = 0;

    public static void setEnabled(boolean value) { enabled = value; }
    public static boolean isEnabled() { return enabled; }
    public static void toggle() { enabled = !enabled; }

    // VFX tracking
    public static void registerVfx() { activeVfxCount++; }
    public static void unregisterVfx() { activeVfxCount = Math.max(0, activeVfxCount - 1); }
    public static int getActiveVfxCount() { return activeVfxCount; }

    // Clone tracking
    public static void registerClone() { activeCloneCount++; }
    public static void unregisterClone() { activeCloneCount = Math.max(0, activeCloneCount - 1); }
    public static int getActiveCloneCount() { return activeCloneCount; }

    // Render time tracking
    public static void beginFrame() { lastFrameNs = System.nanoTime(); }
    public static void endFrame() { frameTimeNs = System.nanoTime() - lastFrameNs; }
    public static float getFrameTimeMs() { return frameTimeNs / 1_000_000f; }

    // Memory
    public static long getUsedMemoryMb() {
        Runtime rt = Runtime.getRuntime();
        return (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024);
    }
    public static long getMaxMemoryMb() {
        return Runtime.getRuntime().maxMemory() / (1024 * 1024);
    }
}