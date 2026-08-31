package com.example.shinobicore.modules.movement.server;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class MovementServerMirror {
    private static final Map<UUID, MovementPose> POSES = new ConcurrentHashMap<>();
    private static final Map<UUID, DrainAccumulator> DRAINS = new ConcurrentHashMap<>();

    private MovementServerMirror() {}

    public static void init() {
        ShinobiLogger.module("movement", "Server mirror initialized.");
    }

    public static void tick(MinecraftServer server) {
        for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
            UUID id = p.getUuid();
            MovementPose pose = POSES.getOrDefault(id, MovementPose.NORMAL);
            
            if (pose == MovementPose.NORMAL) {
                DRAINS.remove(id);
                continue;
            }

            CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
                if (!chakra.isChakraModeActive(p) || chakra.isExhausted(p)) {
                    forceStopParkour(p);
                    return;
                }

                double rate = getDrainRate(pose);
                if (rate <= 0) {
                    DRAINS.remove(id);
                    return;
                }

                DrainAccumulator acc = DRAINS.computeIfAbsent(id, k -> new DrainAccumulator(rate));
                int toSpend = acc.tick(1.0 / 20.0);
                
                if (toSpend > 0) {
                    if (!chakra.trySpend(p, toSpend)) {
                        forceStopParkour(p);
                    }
                }
            });
        }
    }

    public static void handleAction(ServerPlayerEntity player, int actionId, float yaw, double vx, double vz) {
        UUID id = player.getUuid();
        switch (actionId) {
            case MovementActions.START_WATER_WALK:
            case MovementActions.START_WALL_RUN:
            case MovementActions.START_EDGE_GRAB:
                POSES.put(id, getPoseForAction(actionId));
                break;
            case MovementActions.STOP_WATER_WALK:
            case MovementActions.STOP_WALL_RUN:
            case MovementActions.STOP_SLIDE:
            case MovementActions.STOP_ROLL:
            case MovementActions.STOP_EDGE_GRAB:
                POSES.put(id, MovementPose.NORMAL);
                break;
        }
    }

    public static void forceStopParkour(ServerPlayerEntity player) {
        UUID id = player.getUuid();
        POSES.put(id, MovementPose.NORMAL);
        DRAINS.remove(id);
    }

    public static void cleanupPlayer(UUID uuid) {
        POSES.remove(uuid);
        DRAINS.remove(uuid);
    }

    // --- Exposed getters for Commands ---
    public static MovementPose getPose(UUID uuid) {
        return POSES.getOrDefault(uuid, MovementPose.NORMAL);
    }

    public static double getDrainAccumulator(UUID uuid) {
        DrainAccumulator acc = DRAINS.get(uuid);
        return acc != null ? acc.getAccumulator() : 0.0;
    }

    private static MovementPose getPoseForAction(int actionId) {
        return switch (actionId) {
            case MovementActions.START_WATER_WALK -> MovementPose.WATER_WALKING;
            case MovementActions.START_WALL_RUN -> MovementPose.WALL_RUNNING;
            case MovementActions.START_EDGE_GRAB -> MovementPose.EDGE_GRABBING;
            default -> MovementPose.NORMAL;
        };
    }

    private static double getDrainRate(MovementPose pose) {
        return switch (pose) {
            case WATER_WALKING -> MovementConfig.WATER_WALK_DRAIN;
            case WALL_RUNNING -> MovementConfig.WALL_RUN_DRAIN;
            default -> 0.0;
        };
    }
}