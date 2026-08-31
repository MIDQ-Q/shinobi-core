// SHINOBICORE:SPRINT2:FILE
package com.example.shinobicore.chakra.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

/**
 * SPRINT 2 client-side chakra controller.
 * Handles tick-based regen, drain, exhaustion and mirrors state to legacy HUD.
 */
public final class ChakraClientController {
    private static float currentChakra = 2000.0f;
    private static float maxChakra = 2000.0f;
    private static float fatigue = 0.0f;
    private static boolean chakraMode = false;
    private static boolean exhausted = false;
    private static boolean meditating = false;

    private static float lastSyncedCurrent = -1.0f;
    private static boolean lastSyncedMode = false;

    private ChakraClientController() {}

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraClientController::tickClient);
    }

    public static void tickClient(MinecraftClient client) {
        // [AUTO-FIX] if (!FeatureFlags.chakraV3) return;
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;

        ClientPlayerEntity player = client.player;
        MovementChakraConfig config = MovementChakraConfig.getInstance();
        if (config == null || config.chakra == null) return;

        maxChakra = config.chakra.baseMaxChakra;

        // 1. Passive regen (if not exhausted and not in active drain mode)
        if (!exhausted && !chakraMode) {
            float regen = config.chakra.chakraRegenPerSec / 20.0f;
            if (meditating) regen *= config.chakra.meditationRegenMultiplier;
            currentChakra = Math.min(maxChakra, currentChakra + regen);
        }

        // 2. Exhaustion recovery
        if (exhausted) {
            fatigue -= 2.0f / 20.0f; // Default fatigue recovery
            if (fatigue <= 0.0f) {
                fatigue = 0.0f;
                exhausted = false;
                ShinobiLogger.info("[CHAKRA] Exhaustion ended");
            }
        }
    }

    public static boolean isChakraModeActive() { return chakraMode; }
    public static float getCurrentChakra() { return currentChakra; }
    public static float getMaxChakra() { return maxChakra; }
    public static boolean isExhausted() { return exhausted; }
    public static boolean isMeditating() { return meditating; }

    public static void setMeditating(boolean value) {
        meditating = value;
    }

    public static void toggleChakraMode() {
        chakraMode = !chakraMode;
        ShinobiLogger.info("[CHAKRA] Mode toggled to: " + chakraMode);
    }

    public static boolean consumeChakra(float amount) {
        if (exhausted) return false;
        if (currentChakra < amount) {
            exhausted = true;
            chakraMode = false;
            fatigue = 100.0f;
            ShinobiLogger.info("[CHAKRA] Exhaustion triggered");
            return false;
        }
        currentChakra -= amount;
        return true;
    }
}