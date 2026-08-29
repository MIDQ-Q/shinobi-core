package com.example.shinobicore.progression;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;

public final class JutsuUsageXPProvider {

    private JutsuUsageXPProvider() {}

    public static void init() {
        JutsuCastEvent.EVENT.register((player, jutsuId, statType) -> {
            try {
                PlayerProgressionComponent comp = ProgressionSystem.get(player);
                String profKey = "prof:" + jutsuId;
                int currentProf = comp.getStat(profKey);
                comp.addStat(profKey, 1);

                int baseXP = 5;
                int xp = baseXP + (currentProf / 2);
                ProgressionSystem.awardXP(player, xp);

                // Feed real stat XP so Stats tab progress bars move
                IStatsComponent stats = NinjaComponents.getStats(player);
                if (stats != null) {
                    StatType type = StatType.fromString(statType);
                    if (type != null) {
                        stats.addXp(type, xp);
                    }
                }
                if (stats != null) NinjaComponents.STATS.sync(player, stats);
            } catch (Exception e) {
                ShinobiCore.LOGGER.warn("JutsuUsageXPProvider error: {}", e.getMessage());
            }
        });
        ShinobiCore.LOGGER.info("JutsuUsageXPProvider initialized");
    }
}