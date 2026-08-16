package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;

/**
 * S0-06: Debug logging for all network packets.
 * Logs packet name, direction, and player in debug mode.
 * Enable via /ninja debug network on|off
 */
public class NetworkDebugLogger {
    private static boolean enabled = false;
    private static long packetCount = 0;
    private static long lastResetMs = System.currentTimeMillis();
    private static long packetsPerSecond = 0;

    public static void setEnabled(boolean value) {
        enabled = value;
        ShinobiCore.LOGGER.info("[NET-DEBUG] Packet logging {}", value ? "ENABLED" : "DISABLED");
    }

    public static boolean isEnabled() { return enabled; }

    public static void logPacket(String packetName, String direction, String playerName) {
        if (!enabled) return;
        packetCount++;
        long now = System.currentTimeMillis();
        if (now - lastResetMs >= 1000) {
            packetsPerSecond = packetCount;
            packetCount = 0;
            lastResetMs = now;
        }
        ShinobiCore.LOGGER.debug("[NET] {} {} player={} ({} p/s)",
                direction, packetName, playerName, packetsPerSecond);
    }

    public static void logPacket(String packetName, String direction, String playerName, String details) {
        if (!enabled) return;
        packetCount++;
        long now = System.currentTimeMillis();
        if (now - lastResetMs >= 1000) {
            packetsPerSecond = packetCount;
            packetCount = 0;
            lastResetMs = now;
        }
        ShinobiCore.LOGGER.debug("[NET] {} {} player={} [{}] ({} p/s)",
                direction, packetName, playerName, details, packetsPerSecond);
    }

    public static long getPacketsPerSecond() { return packetsPerSecond; }
}