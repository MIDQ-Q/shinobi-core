package com.example.shinobicore.modules.jutsu.cooldown;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuCooldownService {
    private static final Map<UUID, Map<String, CooldownEntry>> COOLDOWNS = new ConcurrentHashMap<>();
    private static final int MIN_COOLDOWN_TICKS = 1; // Never 0 to prevent spam

    public static void init() {
        ShinobiLogger.module("jutsu", "JutsuCooldownService initialized.");
    }

    public static boolean isOnCooldown(UUID playerId, String jutsuId) {
        Map<String, CooldownEntry> playerCds = COOLDOWNS.get(playerId);
        if (playerCds == null) return false;
        CooldownEntry entry = playerCds.get(jutsuId);
        return entry != null && !entry.isFinished();
    }

    public static int getRemainingTicks(UUID playerId, String jutsuId) {
        Map<String, CooldownEntry> playerCds = COOLDOWNS.get(playerId);
        if (playerCds == null) return 0;
        CooldownEntry entry = playerCds.get(jutsuId);
        return entry != null ? Math.max(0, entry.remainingTicks()) : 0;
    }

    public static void startCooldown(UUID playerId, String jutsuId, int maxTicks) {
        int finalTicks = Math.max(MIN_COOLDOWN_TICKS, maxTicks);
        COOLDOWNS.computeIfAbsent(playerId, k -> new ConcurrentHashMap<>())
                 .put(jutsuId, new CooldownEntry(jutsuId, finalTicks, finalTicks));
    }

    public static void serverTick(MinecraftServer server) {
        for (Map.Entry<UUID, Map<String, CooldownEntry>> playerEntry : COOLDOWNS.entrySet()) {
            Map<String, CooldownEntry> playerCds = playerEntry.getValue();
            playerCds.entrySet().removeIf(entry -> {
                CooldownEntry cd = entry.getValue();
                if (cd.isFinished()) return true;
                entry.setValue(new CooldownEntry(cd.jutsuId(), cd.remainingTicks() - 1, cd.maxTicks()));
                return false;
            });
        }
    }

    public static void resetAll(ServerPlayerEntity player) {
        COOLDOWNS.remove(player.getUuid());
    }
}