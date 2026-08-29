package com.example.shinobicore.combat;

import net.minecraft.server.network.ServerPlayerEntity;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/**
 * SERVER SIDE (minimal).
 * Client is authoritative for wall physics. Server only tracks pose state
 * and cleans up on disconnect.
 */
public final class WallRunManager {
    private static final Set<UUID> ON_WALL = new HashSet<>();
    private WallRunManager() {}

    public static void onAction(ServerPlayerEntity player, int action) {
        if (action == ParkourActions.WALL_RUN) {
            ON_WALL.add(player.getUuid());
        } else if (action == ParkourActions.WALL_JUMP) {
            ON_WALL.remove(player.getUuid());
            // NO velocity application here - client already did it
        }
    }

    public static void tickPlayer(ServerPlayerEntity player) {
        // Intentionally empty. Physics is handled on the client.
        // Kept for API compatibility with CombatBootstrap.
    }

    public static void clear(UUID uuid) {
        ON_WALL.remove(uuid);
    }

    public static boolean isOnWall(UUID uuid) {
        return ON_WALL.contains(uuid);
    }
}