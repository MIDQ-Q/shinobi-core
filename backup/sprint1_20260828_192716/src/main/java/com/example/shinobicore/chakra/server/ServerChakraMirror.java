// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.chakra.server;

import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Server-side chakra mirror.
 * 
 * RULES:
 * - Server does NOT tick regen (client is authoritative)
 * - Server does NOT spend chakra for movement (client is authoritative)
 * - Server ONLY: stores, validates, sanitizes, logs suspicious values
 * - On player join: send stored values to client (Script 05)
 */
public final class ServerChakraMirror {

    private static boolean registered = false;
    private static final float MAX_CHAKRA_UPPER_LIMIT = 1.1f; // allow 10% margin for rounding
    private static final float MAX_FATIGUE = 100.0f;

    private ServerChakraMirror() {}

    public static void register() {
        if (registered) return;
        registered = true;

        // Log chakra state on player join (packet sending is in ModPackets.registerServer)
        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            ServerPlayerEntity player = handler.player;
            IChakraComponent chakra = NinjaComponents.getChakra(player);
            if (chakra != null) {
                ShinobiLogger.info("[CHAKRA-MIRROR] Player %s joined: chakra=%.0f/%.0f fatigue=%.0f mode=%s",
                    player.getName().getString(),
                    chakra.getCurrentChakra(),
                    chakra.getMaxChakra(),
                    chakra.getFatigue(),
                    chakra.isChakraMode() ? "ON" : "OFF");
            }
        });

        ShinobiLogger.info("[CHAKRA-MIRROR] ServerChakraMirror registered");
    }

    /**
     * Called when client sends CHAKRA_CLIENT_STATE packet.
     * All buffer reading MUST happen BEFORE this method is called.
     */
    public static void updateFromClient(ServerPlayerEntity player,
            float currentChakra, float fatigue,
            boolean chakraMode, boolean exhausted, boolean meditating) {

        if (player == null) return;

        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra == null) return;

        // === SANITIZE ===
        currentChakra = sanitizeFloat(currentChakra, "currentChakra", player);
        fatigue = sanitizeFloat(fatigue, "fatigue", player);

        // === VALIDATE RANGES ===
        float maxChakra = chakra.getMaxChakra();

        if (currentChakra < 0) {
            logSuspicious(player, "currentChakra negative: " + currentChakra);
            currentChakra = 0;
        }
        if (currentChakra > maxChakra * MAX_CHAKRA_UPPER_LIMIT) {
            logSuspicious(player, "currentChakra exceeds max: " + currentChakra + " > " + maxChakra);
            currentChakra = maxChakra;
        }
        if (fatigue < 0) {
            logSuspicious(player, "fatigue negative: " + fatigue);
            fatigue = 0;
        }
        if (fatigue > MAX_FATIGUE) {
            logSuspicious(player, "fatigue exceeds max: " + fatigue);
            fatigue = MAX_FATIGUE;
        }

        // === STORE (server is a MIRROR, not authoritative) ===
        chakra.setCurrentChakra(currentChakra);
        chakra.setFatigue(fatigue);
        chakra.setChakraMode(chakraMode);
        chakra.setExhausted(exhausted);
        chakra.setMeditating(meditating);
    }

    /**
     * Called on admin command: /shinobicore chakra set/add/mode/reset
     */
    public static void applyAdminSet(ServerPlayerEntity player,
            float newCurrent, float newMax, float newFatigue,
            boolean newMode, boolean newExhausted) {

        if (player == null) return;

        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra == null) return;

        // Sanitize
        newCurrent = sanitizeFloat(newCurrent, "admin.current", player);
        newMax = sanitizeFloat(newMax, "admin.max", player);
        newFatigue = sanitizeFloat(newFatigue, "admin.fatigue", player);

        // Clamp
        newMax = Math.max(1.0f, newMax);
        newCurrent = Math.max(0, Math.min(newCurrent, newMax));
        newFatigue = Math.max(0, Math.min(newFatigue, MAX_FATIGUE));

        // Store
        chakra.setMaxChakra(newMax);
        chakra.setCurrentChakra(newCurrent);
        chakra.setFatigue(newFatigue);
        chakra.setChakraMode(newMode);
        chakra.setExhausted(newExhausted);

        ShinobiLogger.info("[CHAKRA-ADMIN] %s: set chakra=%.0f/%.0f fatigue=%.0f mode=%s",
            player.getName().getString(), newCurrent, newMax, newFatigue, newMode ? "ON" : "OFF");

        // TODO Script 05: Send CHAKRA_ADMIN_SET packet to client
    }

    // === HELPERS ===

    private static float sanitizeFloat(float value, String fieldName, ServerPlayerEntity player) {
        if (Float.isNaN(value)) {
            logSuspicious(player, fieldName + " is NaN");
            return 0.0f;
        }
        if (Float.isInfinite(value)) {
            logSuspicious(player, fieldName + " is Infinite");
            return 0.0f;
        }
        return value;
    }

    private static void logSuspicious(ServerPlayerEntity player, String message) {
        ShinobiLogger.warn("[CHAKRA-SUS] %s: %s", player.getName().getString(), message);
    }
}