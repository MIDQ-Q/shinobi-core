package com.example.shinobicore.modules.jutsu.cast;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.cooldown.JutsuCooldownService;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import com.example.shinobicore.modules.jutsu.requirement.JutsuRequirementService;
import com.example.shinobicore.modules.jutsu.requirement.RequirementCheckResult;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuCastService {
    private static final JutsuCastService INSTANCE = new JutsuCastService();
    private final Map<UUID, JutsuCastSession> activeSessions = new ConcurrentHashMap<>();

    public static JutsuCastService instance() { return INSTANCE; }

    public void requestCast(ServerPlayerEntity player, String jutsuId, int slot, long pressTimestampMs, float yaw, float pitch) {
        JutsuDefinition def = JutsuRegistry.get(jutsuId).orElse(null);
        if (def == null) {
            ShinobiLogger.error("jutsu", "Attempted to cast unknown jutsu: " + jutsuId, null);
            return;
        }

        UUID uuid = player.getUuid();
        JutsuCastSession current = activeSessions.get(uuid);

        if (current != null && !current.isFinished()) {
            current.queueNext(jutsuId);
            ShinobiLogger.module("jutsu", "Queued jutsu " + jutsuId + " for player " + uuid);
            return;
        }

        // Validate requirements before starting
        RequirementCheckResult check = JutsuRequirementService.check(player, def);
        if (!check.ok()) {
            ShinobiLogger.module("jutsu", "Cast rejected for " + jutsuId + ". Reason: " + check.failReason());
            // TODO: Send packet to client to show fail reason (e.g., "Not enough chakra")
            return;
        }

        JutsuCastSession newSession = new JutsuCastSession(uuid, jutsuId, slot, yaw, pitch);
        activeSessions.put(uuid, newSession);
        ShinobiLogger.module("jutsu", "Started cast: " + jutsuId + " for player " + uuid);
    }

    public void startCooldownFor(UUID playerId, String jutsuId, int maxTicks) {
        JutsuCooldownService.startCooldown(playerId, jutsuId, maxTicks);
    }

    public void cancelCast(ServerPlayerEntity player, String reason) {
        JutsuCastSession session = activeSessions.get(player.getUuid());
        if (session != null) {
            session.cancel(reason);
        }
    }

    public void serverTick(MinecraftServer server) {
        activeSessions.entrySet().removeIf(entry -> {
            ServerPlayerEntity player = server.getPlayerManager().getPlayer(entry.getKey());
            if (player == null) return true;

            JutsuCastSession session = entry.getValue();
            session.tick(player);
            
            return session.isFinished();
        });
    }
}