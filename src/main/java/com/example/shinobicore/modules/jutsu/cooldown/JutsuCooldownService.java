package com.example.shinobicore.modules.jutsu.cooldown;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.executor.CooldownSystem;
import java.util.UUID;

/**
 * Thin wrapper that bridges the new module API with the existing
 * CooldownSystem. All actual state lives in CooldownSystem.
 */
public final class JutsuCooldownService {
    private JutsuCooldownService() {}

    public static void init() {
        ShinobiCore.LOGGER.info("[JutsuCooldown] Ready.");
    }

    public static boolean isOnCooldown(UUID player, String jutsuId) {
        return CooldownSystem.isOnCooldown(player, jutsuId);
    }

    public static int getRemaining(UUID player, String jutsuId) {
        return CooldownSystem.getRemaining(player, jutsuId);
    }

    public static void start(UUID player, String jutsuId, int ticks) {
        CooldownSystem.start(player, jutsuId, ticks);
    }

    public static void tick() {
        // CooldownSystem.tick() is called in JutsuModule.serverTick
    }

    public static void clear(UUID player) {
        CooldownSystem.clear(player);
    }

    public static void reduceAll(UUID player, int ticks) {
        CooldownSystem.reduceAll(player, ticks);
    }
}