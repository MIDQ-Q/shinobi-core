package com.example.shinobicore.progression;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.command.ProgressionCommands;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Central progression utilities: XP awarding, level-up checks,
 * and non-linear XP curve.
 * HLD Section 10 (Progression System).
 */
public final class ProgressionSystem {

    private ProgressionSystem() {}

    /** Get the progression component for a player. */
    public static PlayerProgressionComponent get(ServerPlayerEntity player) {
        return ShinobiComponents.PROGRESSION.get(player);
    }

    /** Award XP to a player and check for level-ups. */
    public static void awardXP(ServerPlayerEntity player, int amount) {
        if (amount <= 0) return;
        PlayerProgressionComponent comp = get(player);
        comp.addXP(amount);
        checkLevelUp(player, comp);
    }

    /**
     * Non-linear XP curve:
     * - Levels 1-10: fast growth
     * - Levels 11-30: slowdown
     * - Levels 31-50: acceleration (harder enemies/quests)
     * - Levels 51+: slowdown again
     */
    public static int xpForLevel(int level) {
        if (level <= 10) {
            return 100 + level * 50;
        } else if (level <= 30) {
            return 600 + level * 100;
        } else if (level <= 50) {
            return 2600 + level * 150;
        } else {
            return 5600 + level * 200;
        }
    }

    private static void checkLevelUp(ServerPlayerEntity player, PlayerProgressionComponent comp) {
        int xp = comp.getXp();
        int level = comp.getLevel();
        int needed = xpForLevel(level);

        while (xp >= needed) {
            comp.setLevel(level + 1);
            comp.addSP(1); // +1 SP per level
            level++;
            needed = xpForLevel(level);
            ShinobiCore.LOGGER.info("Player leveled up to {}", level);
        }
    }

    /** Register commands and event listeners. Called from ShinobiCore.onInitialize. */
    public static void init() {
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            ProgressionCommands.register(dispatcher);
        });
        CombatXPProvider.init();
        JutsuUsageXPProvider.init();
        ProgressionEffects.init();
        ShinobiCore.LOGGER.info("ProgressionSystem initialized (Sprint 6)");
    }
}