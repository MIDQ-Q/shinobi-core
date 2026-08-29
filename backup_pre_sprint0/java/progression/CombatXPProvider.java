package com.example.shinobicore.progression;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.enemy.NinjaEnemyEntity;
import net.fabricmc.fabric.api.entity.event.v1.ServerLivingEntityEvents;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Awards XP to the player who kills a ninja enemy.
 * XP amount depends on the enemy's rank (genin/chunin/jonin).
 * HLD Section 10 (Progression System).
 */
public final class CombatXPProvider {

    private CombatXPProvider() {}

    public static void init() {
        // Use AFTER_DEATH (correct event name in Fabric API 1.20.1)
        ServerLivingEntityEvents.AFTER_DEATH.register((entity, source) -> {
            if (!(entity instanceof NinjaEnemyEntity enemy)) return;

            LivingEntity attacker = enemy.getAttacker();
            if (!(attacker instanceof ServerPlayerEntity player)) return;

            // NinjaRank is enum -> convert to String via name()
            String rankName = enemy.getRank() != null ? enemy.getRank().name() : "genin";
            int xp = getXPForRank(rankName);
            ProgressionSystem.awardXP(player, xp);
        });
        ShinobiCore.LOGGER.info("CombatXPProvider initialized");
    }

    private static int getXPForRank(String rank) {
        if (rank == null) return 10;
        return switch (rank.toLowerCase()) {
            case "genin" -> 10;
            case "chunin" -> 25;
            case "jonin" -> 50;
            default -> 10;
        };
    }
}