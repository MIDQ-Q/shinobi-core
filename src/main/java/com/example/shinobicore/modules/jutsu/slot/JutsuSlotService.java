package com.example.shinobicore.modules.jutsu.slot;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuSlotService {
    private static final Map<UUID, JutsuLoadout> playerLoadouts = new ConcurrentHashMap<>();

    public static JutsuLoadout getLoadout(ServerPlayerEntity player) {
        return playerLoadouts.computeIfAbsent(player.getUuid(), uuid -> JutsuLoadout.DEFAULT);
    }

    public static void selectSlot(ServerPlayerEntity player, int slotIndex) {
        if (slotIndex < 0 || slotIndex > 2) return;
        UUID uuid = player.getUuid();
        JutsuLoadout current = getLoadout(player);
        playerLoadouts.put(uuid, current.withSelected(slotIndex));
        ShinobiLogger.module("jutsu", "Player " + uuid + " selected slot " + slotIndex);
    }

    public static void cycleSlot(ServerPlayerEntity player) {
        UUID uuid = player.getUuid();
        JutsuLoadout current = getLoadout(player);
        int nextSlot = (current.selectedSlot() + 1) % 3;
        playerLoadouts.put(uuid, current.withSelected(nextSlot));
    }

    public static boolean assignJutsu(ServerPlayerEntity player, int slotIndex, String jutsuId) {
        if (slotIndex < 0 || slotIndex > 2) return false;
        
        boolean isLearned = true; 
        var progOpt = CoreServices.get(com.example.shinobicore.core.api.ProgressionApi.class);
        if (progOpt.isPresent() && jutsuId != null) {
            // TODO: isLearned = progOpt.get().isNodeUnlocked(player, jutsuId);
        }

        if (!isLearned) {
            ShinobiLogger.module("jutsu", "Player " + player.getUuid() + " tried to assign unlearned jutsu: " + jutsuId);
            return false;
        }

        if (jutsuId != null && !JutsuRegistry.get(jutsuId).isPresent()) {
            ShinobiLogger.error("jutsu", "Attempted to assign unknown jutsu: " + jutsuId, null);
            return false;
        }

        UUID uuid = player.getUuid();
        JutsuLoadout current = getLoadout(player);
        playerLoadouts.put(uuid, current.withSlot(slotIndex, jutsuId));
        ShinobiLogger.module("jutsu", "Assigned " + jutsuId + " to slot " + slotIndex + " for player " + uuid);
        return true;
    }

    public static void resetToDefaults(ServerPlayerEntity player) {
        playerLoadouts.put(player.getUuid(), JutsuLoadout.DEFAULT);
    }
}