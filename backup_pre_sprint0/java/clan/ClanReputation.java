package com.example.shinobicore.clan;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.HashMap;
import java.util.Map;

/**
 * S12-06: Clan reputation system.
 * Tracks player reputation with each clan (-100 to +100).
 * Stored in NinjaPlayerData for persistence.
 */
public class ClanReputation {
    public static final int MIN_REP = -100;
    public static final int MAX_REP = 100;
    public static final int NEUTRAL = 0;
    public static final int FRIENDLY_THRESHOLD = 50;
    public static final int HOSTILE_THRESHOLD = -50;

    private static final String[] CLAN_IDS = {
        "uchiha", "hyuga", "uzumaki", "senju", "nara",
        "aburame", "inuzuka", "akimichi", "hatake"
    };

    /**
     * Get player's reputation with a specific clan.
     */
    public static int getReputation(ServerPlayerEntity player, String clanId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        Map<String, Integer> repMap = data.getClanReputation();
        return repMap.getOrDefault(clanId, NEUTRAL);
    }

    /**
     * Modify player's reputation with a clan.
     * @return New reputation value
     */
    public static int modifyReputation(ServerPlayerEntity player, String clanId, int amount) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        Map<String, Integer> repMap = data.getClanReputation();
        int current = repMap.getOrDefault(clanId, NEUTRAL);
        int newRep = Math.max(MIN_REP, Math.min(MAX_REP, current + amount));
        repMap.put(clanId, newRep);
        data.setClanReputation(repMap);

        // Notify player of significant changes
        if (Math.abs(amount) >= 10) {
            String clanName = clanId.substring(0, 1).toUpperCase() + clanId.substring(1);
            String change = amount > 0 ? "+" + amount : String.valueOf(amount);
            player.sendMessage(Text.literal("\u00a7e" + clanName + " reputation: " + change + " (now " + newRep + ")"), false);
        }

        return newRep;
    }

    /**
     * Get standing with a clan based on reputation.
     */
    public static Standing getStanding(ServerPlayerEntity player, String clanId) {
        int rep = getReputation(player, clanId);
        if (rep >= FRIENDLY_THRESHOLD) return Standing.FRIENDLY;
        if (rep <= HOSTILE_THRESHOLD) return Standing.HOSTILE;
        return Standing.NEUTRAL;
    }

    /**
     * Check if player is friendly with a clan.
     */
    public static boolean isFriendly(ServerPlayerEntity player, String clanId) {
        return getStanding(player, clanId) == Standing.FRIENDLY;
    }

    /**
     * Check if player is hostile with a clan.
     */
    public static boolean isHostile(ServerPlayerEntity player, String clanId) {
        return getStanding(player, clanId) == Standing.HOSTILE;
    }

    /**
     * Get reputation multiplier for clan-specific effects.
     * Friendly: 1.2x, Neutral: 1.0x, Hostile: 0.8x
     */
    public static float getReputationMultiplier(ServerPlayerEntity player, String clanId) {
        Standing standing = getStanding(player, clanId);
        switch (standing) {
            case FRIENDLY: return 1.2f;
            case HOSTILE: return 0.8f;
            default: return 1.0f;
        }
    }

    /**
     * Reset all clan reputations to neutral.
     */
    public static void resetAll(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        Map<String, Integer> repMap = new HashMap<>();
        for (String clanId : CLAN_IDS) {
            repMap.put(clanId, NEUTRAL);
        }
        data.setClanReputation(repMap);
        player.sendMessage(Text.literal("\u00a77All clan reputations reset to neutral."), false);
    }

    /**
     * Get all clan reputations for display.
     */
    public static Map<String, Integer> getAllReputations(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return new HashMap<>(data.getClanReputation());
    }

    public enum Standing {
        FRIENDLY("\u00a7aFriendly"),
        NEUTRAL("\u00a77Neutral"),
        HOSTILE("\u00a7cHostile");

        private final String displayName;

        Standing(String displayName) {
            this.displayName = displayName;
        }

        public String getDisplayName() {
            return displayName;
        }
    }
}