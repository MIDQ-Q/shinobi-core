package com.example.shinobicore.network;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Rate limiter for incoming packets to prevent spam/flooding.
 */
public final class PacketRateLimiter {
    private static final Logger LOGGER = LoggerFactory.getLogger("ShinobiCore-RateLimiter");
    private static final Map<UUID, Map<String, Long>> LAST_PACKET = new ConcurrentHashMap<>();
    private static final long CLEANUP_INTERVAL_MS = 60_000;
    private static volatile long lastCleanup = System.currentTimeMillis();

    private PacketRateLimiter() {}

    public static boolean allow(UUID playerId, String packetId, long minIntervalMs) {
        long now = System.currentTimeMillis();

        if (now - lastCleanup > CLEANUP_INTERVAL_MS) {
            cleanup();
            lastCleanup = now;
        }

        Map<String, Long> playerPackets = LAST_PACKET.computeIfAbsent(playerId, k -> new ConcurrentHashMap<>());
        Long lastTime = playerPackets.get(packetId);

        if (lastTime != null && (now - lastTime) < minIntervalMs) {
            LOGGER.debug("[RATE-LIMIT] player={}, packet={}, elapsed={}ms < {}ms",
                playerId, packetId, now - lastTime, minIntervalMs);
            return false;
        }

        playerPackets.put(packetId, now);
        return true;
    }

    public static boolean allow(UUID playerId, String packetId) {
        return allow(playerId, packetId, 50);
    }

    public static void removePlayer(UUID playerId) {
        LAST_PACKET.remove(playerId);
    }

    public static void clear() {
        LAST_PACKET.clear();
    }

    private static void cleanup() {
        long now = System.currentTimeMillis();
        LAST_PACKET.entrySet().removeIf(playerEntry -> {
            playerEntry.getValue().entrySet().removeIf(e -> (now - e.getValue()) > CLEANUP_INTERVAL_MS);
            return playerEntry.getValue().isEmpty();
        });
    }
}