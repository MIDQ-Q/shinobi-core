package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * S2-08: Fast control recovery after landing.
 * 
 * After a significant fall, the player enters a brief recovery window
 * (3 ticks = 0.15 sec) where movement penalties are reduced and
 * the player regains full control quickly.
 * 
 * This prevents the unpleasant "slippery landing" feeling and
 * ensures parkour + combat don't conflict.
 */
public class LandingControlRecovery {
    private static final Map<UUID, Integer> RECOVERY_TICKS = new HashMap<>();
    private static final Map<UUID, Boolean> WAS_ON_GROUND = new HashMap<>();
    private static final Map<UUID, Float> LAST_FALL_VEL = new HashMap<>();
    
    /** Recovery window duration in ticks (0.15 sec) */
    private static final int RECOVERY_DURATION = 3;
    
    /** Minimum fall velocity to trigger recovery (blocks/tick) */
    private static final float MIN_FALL_VEL = -0.3f;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(LandingControlRecovery::tick);
    }

    private static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        UUID id = player.getUuid();
        boolean onGround = player.isOnGround();
        boolean wasOnGround = WAS_ON_GROUND.getOrDefault(id, true);

        // Track fall velocity while airborne
        if (!onGround) {
            float vy = (float) player.getVelocity().y;
            if (vy < 0) {
                LAST_FALL_VEL.put(id, vy);
            }
        }

        // Detect landing: transition from air to ground
        if (!wasOnGround && onGround) {
            float fallVel = LAST_FALL_VEL.getOrDefault(id, 0f);
            if (fallVel < MIN_FALL_VEL) {
                RECOVERY_TICKS.put(id, RECOVERY_DURATION);
            }
            LAST_FALL_VEL.remove(id);
        }

        // Tick recovery countdown
        if (RECOVERY_TICKS.containsKey(id)) {
            int ticks = RECOVERY_TICKS.get(id);
            if (ticks <= 0) {
                RECOVERY_TICKS.remove(id);
            } else {
                RECOVERY_TICKS.put(id, ticks - 1);
            }
        }

        WAS_ON_GROUND.put(id, onGround);
    }

    /**
     * Check if player is in landing recovery window.
     * Other systems can use this to skip casting interruptions,
     * reduce movement penalties, etc.
     */
    public static boolean isRecovering(UUID id) {
        Integer ticks = RECOVERY_TICKS.get(id);
        return ticks != null && ticks > 0;
    }

    public static boolean isRecovering(ClientPlayerEntity player) {
        if (player == null) return false;
        return isRecovering(player.getUuid());
    }

    /**
     * Get remaining recovery ticks (0 if not recovering).
     */
    public static int getRecoveryTicks(UUID id) {
        return RECOVERY_TICKS.getOrDefault(id, 0);
    }

    /**
     * Cleanup on player disconnect to prevent memory leaks.
     */
    public static void cleanup(UUID id) {
        RECOVERY_TICKS.remove(id);
        WAS_ON_GROUND.remove(id);
        LAST_FALL_VEL.remove(id);
    }

    /**
     * Cleanup all data (called on disconnect).
     */
    public static void cleanupAll() {
        RECOVERY_TICKS.clear();
        WAS_ON_GROUND.clear();
        LAST_FALL_VEL.clear();
    }
}