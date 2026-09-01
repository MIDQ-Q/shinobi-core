package com.example.shinobicore.network;

import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.stat.StatType;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Validates incoming packet data before processing.
 * All read operations MUST happen BEFORE server.execute().
 * Validation MUST happen BEFORE server.execute().
 */
public final class PacketValidator {
    private static final Logger LOGGER = LoggerFactory.getLogger("ShinobiCore-PacketValidator");
    private static final int MAX_STRING_LENGTH = 128;
    private static final int MAX_COMBO_STEP = 10;
    private static final int MAX_SLOT_INDEX = 4;
    private static final int MAX_LOADOUT_SET = 1;

    private PacketValidator() {}

    public static String safeReadString(PacketByteBuf buf, int maxLen) {
        try {
            return buf.readString(Math.min(maxLen, MAX_STRING_LENGTH));
        } catch (Exception e) {
            LOGGER.warn("Failed to read string from packet: {}", e.getMessage());
            return "";
        }
    }

    public static String safeReadString(PacketByteBuf buf) {
        return safeReadString(buf, MAX_STRING_LENGTH);
    }

    public static boolean validComboStep(int step) {
        return step >= 0 && step <= MAX_COMBO_STEP;
    }

    public static boolean validStyleId(String styleId) {
        if (styleId == null || styleId.isEmpty()) return false;
        return switch (styleId) {
            case "standard", "strong_fist",
                 "aggressive", "seigan", "iai" -> true;
            default -> false;
        };
    }

    public static boolean validJutsuId(String jutsuId) {
        if (jutsuId == null || jutsuId.isEmpty()) return true;
        return JutsuRegistry.get(jutsuId) != null;
    }

    public static boolean validSlotIndex(int slot) {
        return slot >= 0 && slot <= MAX_SLOT_INDEX;
    }

    public static boolean validLoadoutSet(int set) {
        return set >= 0 && set <= MAX_LOADOUT_SET;
    }

    public static boolean validStatId(String statId) {
        if (statId == null || statId.isEmpty()) return false;
        for (StatType s : StatType.values()) {
            if (s.getId().equals(statId)) return true;
        }
        return false;
    }

    public static boolean validPlayerState(ServerPlayerEntity player) {
        if (player == null) return false;
        if (player.isDead()) return false;
        if (player.getWorld() == null) return false;
        if (player.getWorld().isClient()) return false;
        return true;
    }

    public static boolean validCombatState(ServerPlayerEntity player) {
        if (!validPlayerState(player)) return false;
        if (player.isSpectator()) return false;
        return true;
    }

    public static void logRejection(ServerPlayerEntity player, String packetName, String reason) {
        LOGGER.warn("[PACKET-REJECT] player={}, packet={}, reason={}",
            player != null ? player.getName().getString() : "null",
            packetName, reason);
    }
}