// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.movement.server;

import com.example.shinobicore.movement.common.MovementActionType;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.util.ShinobiLogger;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Server-side movement mirror.
 * 
 * RULES:
 * - Server does NOT control movement (client is authoritative)
 * - Server only LOGS events and stores state for future multiplayer visual
 * - Server does NOT rubberband or teleport player
 * - Server can soft-repeat physics if serverMirrorPhysics is enabled
 */
public final class ServerMovementMirror {

    private ServerMovementMirror() {}

    private static boolean registered = false;

    private static final Map<UUID, MovementPhase> playerPhases = new HashMap<>();
    private static final Map<UUID, Long> lastHeartbeat = new HashMap<>();

    public static void register() {
        if (registered) return;
        registered = true;

        net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents.DISCONNECT.register(
            (handler, server) -> {
                UUID id = handler.player.getUuid();
                playerPhases.remove(id);
                lastHeartbeat.remove(id);
            }
        );

        ShinobiLogger.info("[MOVEMENT] ServerMovementMirror registered");
    }

    public static void onAction(ServerPlayerEntity player, MovementActionType action,
            Vec3d wallNormal) {
        if (player == null || action == null) return;

        UUID id = player.getUuid();

        switch (action) {
            case WATER_START -> {
                playerPhases.put(id, MovementPhase.WATER_WALKING);
                ShinobiLogger.debug("[MOVEMENT] %s started water walk", player.getName().getString());
            }
            case WATER_STOP -> {
                playerPhases.put(id, MovementPhase.NORMAL);
                ShinobiLogger.debug("[MOVEMENT] %s stopped water walk", player.getName().getString());
            }
            case WALL_START -> {
                playerPhases.put(id, MovementPhase.WALL_RUNNING);
                ShinobiLogger.debug("[MOVEMENT] %s started wall run", player.getName().getString());
            }
            case WALL_STOP, WALL_JUMP -> {
                playerPhases.put(id, MovementPhase.NORMAL);
                ShinobiLogger.debug("[MOVEMENT] %s stopped wall run", player.getName().getString());
            }
            case SLIDE_START -> {
                playerPhases.put(id, MovementPhase.SLIDING);
                ShinobiLogger.debug("[MOVEMENT] %s started slide", player.getName().getString());
            }
            case SLIDE_STOP -> {
                playerPhases.put(id, MovementPhase.NORMAL);
                ShinobiLogger.debug("[MOVEMENT] %s stopped slide", player.getName().getString());
            }
            case CRAWL_START -> {
                playerPhases.put(id, MovementPhase.CRAWLING);
                ShinobiLogger.debug("[MOVEMENT] %s started crawl", player.getName().getString());
            }
            case CRAWL_STOP -> {
                playerPhases.put(id, MovementPhase.NORMAL);
                ShinobiLogger.debug("[MOVEMENT] %s stopped crawl", player.getName().getString());
            }
            case ROLL_START -> {
                playerPhases.put(id, MovementPhase.ROLLING);
                ShinobiLogger.debug("[MOVEMENT] %s started roll", player.getName().getString());
            }
            case ROLL_STOP -> {
                playerPhases.put(id, MovementPhase.NORMAL);
                ShinobiLogger.debug("[MOVEMENT] %s stopped roll", player.getName().getString());
            }
            case DODGE_LEFT -> {
                playerPhases.put(id, MovementPhase.DODGING);
                ShinobiLogger.debug("[MOVEMENT] %s dodged left", player.getName().getString());
            }
            case DODGE_RIGHT -> {
                playerPhases.put(id, MovementPhase.DODGING);
                ShinobiLogger.debug("[MOVEMENT] %s dodged right", player.getName().getString());
            }
            case CHARGED_JUMP_START -> {
                playerPhases.put(id, MovementPhase.CHARGING_JUMP);
                ShinobiLogger.debug("[MOVEMENT] %s started charged jump", player.getName().getString());
            }
            case CHARGED_JUMP_RELEASE -> {
                playerPhases.put(id, MovementPhase.NORMAL);
                ShinobiLogger.debug("[MOVEMENT] %s released charged jump", player.getName().getString());
            }
            case DOUBLE_JUMP -> {
                ShinobiLogger.debug("[MOVEMENT] %s double jumped", player.getName().getString());
            }
            case EDGE_GRAB_START -> {
                playerPhases.put(id, MovementPhase.EDGE_GRABBING);
                ShinobiLogger.debug("[MOVEMENT] %s grabbed edge", player.getName().getString());
            }
            case EDGE_GRAB_STOP -> {
                playerPhases.put(id, MovementPhase.NORMAL);
                ShinobiLogger.debug("[MOVEMENT] %s released edge", player.getName().getString());
            }
            case MEDITATION_START -> {
                playerPhases.put(id, MovementPhase.MEDITATING);
                ShinobiLogger.debug("[MOVEMENT] %s started meditation", player.getName().getString());
            }
            case MEDITATION_STOP -> {
                playerPhases.put(id, MovementPhase.NORMAL);
                ShinobiLogger.debug("[MOVEMENT] %s stopped meditation", player.getName().getString());
            }
            case RESET -> {
                playerPhases.put(id, MovementPhase.NORMAL);
                ShinobiLogger.debug("[MOVEMENT] %s reset movement", player.getName().getString());
            }
            default -> {}
        }
    }

    public static void onHeartbeat(ServerPlayerEntity player, MovementPhase phase,
            boolean onWater, boolean crawling, boolean sliding, boolean meditating) {
        if (player == null) return;
        lastHeartbeat.put(player.getUuid(), System.currentTimeMillis());
        playerPhases.put(player.getUuid(), phase);
    }

    public static MovementPhase getPhase(ServerPlayerEntity player) {
        return playerPhases.getOrDefault(player.getUuid(), MovementPhase.NORMAL);
    }

    public static void resetPlayer(ServerPlayerEntity player) {
        playerPhases.remove(player.getUuid());
        lastHeartbeat.remove(player.getUuid());
    }
}