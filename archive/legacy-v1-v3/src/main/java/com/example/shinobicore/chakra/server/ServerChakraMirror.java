// SHINOBICORE:SPRINT1:FILE
package com.example.shinobicore.chakra.server;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * SPRINT 1 safe server-side chakra mirror.
 *
 * This is not yet an authoritative anti-cheat.
 * It stores a server-side snapshot for debugging and future sync.
 */
public final class ServerChakraMirror {
    public static final float DEFAULT_MAX_CHAKRA = 2000.0f;

    private static final Map<UUID, Data> DATA = new ConcurrentHashMap<>();

    private ServerChakraMirror() {}

    public static class Data {
        public float current = DEFAULT_MAX_CHAKRA;
        public float max = DEFAULT_MAX_CHAKRA;
        public float fatigue = 0.0f;
        public boolean chakraMode = false;
    }

    public static Data get(UUID uuid) {
        return DATA.computeIfAbsent(uuid, id -> new Data());
    }

    public static void set(UUID uuid, float value) {
        Data data = get(uuid);
        data.current = clamp(value, 0.0f, data.max);
    }

    public static void add(UUID uuid, float amount) {
        Data data = get(uuid);
        data.current = clamp(data.current + amount, 0.0f, data.max);
    }

    public static void reset(UUID uuid) {
        DATA.remove(uuid);
    }

    public static void resetAll() {
        DATA.clear();
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }
    // --- SPRINT 1 STUBS FOR LEGACY CALLERS ---

    public static void register() {
        // No-op in Sprint 1. Packet registration handled elsewhere.
    }

    public static void applyAdminSet(ServerPlayerEntity player, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        if (player == null) return;
        updateFromClient(player.getUuid(), current, max, fatigue, mode, exhausted);
    }

    public static void updateFromClient(ServerPlayerEntity player, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        if (player == null) return;
        updateFromClient(player.getUuid(), current, max, fatigue, mode, exhausted);
    }

    public static void updateFromClient(ServerPlayerEntity player, float current, float max, boolean mode, boolean exhausted, boolean meditating) {
        if (player == null) return;
        updateFromClient(player.getUuid(), current, max, 0.0f, mode, exhausted);
    }

    public static void updateFromClient(UUID uuid, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        Data data = get(uuid);
        data.current = clamp(current, 0.0f, max);
        data.max = max;
        data.fatigue = fatigue;
        data.chakraMode = mode;
    }
}