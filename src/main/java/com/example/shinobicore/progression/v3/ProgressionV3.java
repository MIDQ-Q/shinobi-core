// SHINOBICORE:SPRINT18:FILE
package com.example.shinobicore.progression.v3;

import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 18 server-side progression core.
 */
public final class ProgressionV3 {
    private static final Map<UUID, Data> DATA = new ConcurrentHashMap<>();

    private ProgressionV3() {}

    public static class Data {
        public int level = 1;
        public int xp = 0;
        public int sp = 0;

        public Map<String, Integer> statLevels = new ConcurrentHashMap<>();
        public Map<String, Integer> statXp = new ConcurrentHashMap<>();
    }

    public static Data get(UUID uuid) {
        return DATA.computeIfAbsent(uuid, id -> new Data());
    }

    public static Data get(ServerPlayerEntity player) {
        ensureLoaded(player);
        return DATA.computeIfAbsent(player.getUuid(), id -> new Data());
    }

    public static void ensureLoaded(ServerPlayerEntity player) {
        UUID uuid = player.getUuid();

        if (DATA.containsKey(uuid)) {
            return;
        }

        Data loaded = null;

        if (player.getServer() != null) {
            loaded = ProgressionV3Storage.load(player.getServer(), uuid);
        }

        if (loaded == null) {
            loaded = new Data();
        }

        DATA.put(uuid, loaded);
    }

    public static int getXpForNextLevel(int level) {
        return 100 + (level - 1) * 50;
    }

    public static int getStatXpForNextLevel(int level) {
        return 80 + (level - 1) * 40;
    }

    public static void addXp(ServerPlayerEntity player, int amount) {
        if (player == null || amount <= 0) {
            return;
        }

        ensureLoaded(player);
        Data data = get(player.getUuid());

        data.xp += amount;

        while (data.xp >= getXpForNextLevel(data.level)) {
            data.xp -= getXpForNextLevel(data.level);
            data.level++;
            data.sp++;
        }

        if (player.getServer() != null) {
            ProgressionV3Storage.save(player.getServer(), player.getUuid(), data);
        }

        ProgressionV3ServerSync.sendFull(player, data);
    }

    public static void addSp(ServerPlayerEntity player, int amount) {
        if (player == null) {
            return;
        }

        ensureLoaded(player);
        Data data = get(player.getUuid());

        data.sp = Math.max(0, data.sp + amount);

        if (player.getServer() != null) {
            ProgressionV3Storage.save(player.getServer(), player.getUuid(), data);
        }

        ProgressionV3ServerSync.sendFull(player, data);
    }

    public static void addStatXp(ServerPlayerEntity player, String stat, int amount) {
        if (player == null || stat == null || stat.isEmpty() || amount <= 0) {
            return;
        }

        ensureLoaded(player);
        Data data = get(player.getUuid());

        int xp = data.statXp.getOrDefault(stat, 0) + amount;
        int level = data.statLevels.getOrDefault(stat, 1);

        while (xp >= getStatXpForNextLevel(level)) {
            xp -= getStatXpForNextLevel(level);
            level++;
        }

        data.statXp.put(stat, xp);
        data.statLevels.put(stat, level);

        if (player.getServer() != null) {
            ProgressionV3Storage.save(player.getServer(), player.getUuid(), data);
        }

        ProgressionV3ServerSync.sendFull(player, data);
    }

    public static boolean spendSpOnStat(ServerPlayerEntity player, String stat) {
        if (player == null || stat == null || stat.isEmpty()) {
            return false;
        }

        ensureLoaded(player);
        Data data = get(player.getUuid());

        if (data.sp <= 0) {
            return false;
        }

        data.sp--;

        int newLevel = data.statLevels.getOrDefault(stat, 1) + 1;
        data.statLevels.put(stat, newLevel);

        if (player.getServer() != null) {
            ProgressionV3Storage.save(player.getServer(), player.getUuid(), data);
        }

        ProgressionV3ServerSync.sendFull(player, data);

        return true;
    }

    public static void reset(ServerPlayerEntity player) {
        if (player == null) {
            return;
        }

        DATA.remove(player.getUuid());

        if (player.getServer() != null) {
            ProgressionV3Storage.delete(player.getServer(), player.getUuid());
        }

        ensureLoaded(player);
        ProgressionV3ServerSync.sendFull(player, get(player.getUuid()));
    }
}