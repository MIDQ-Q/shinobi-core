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
        if (!FeatureFlags.chakraV3) return;
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

        // 2. Active drain (chakra mode)
        if (chakraMode && !exhausted) {
            float drain = config.chakra.chakraModeDrainPerSec / 20.0f;
            currentChakra -= drain;
        }

        // 3. Exhaustion check
        if (currentChakra <= 0.0f) {
            currentChakra = 0.0f;
            if (chakraMode) {
                chakraMode = false;
                exhausted = true;
                ShinobiLogger.info("[CHAKRA] Exhausted! Mode disabled.");
            }
        }

        // 4. Sync to server (only if changed significantly to save bandwidth)
        boolean needsSync = false;
        if (Math.abs(currentChakra - lastSyncedCurrent) > 1.0f || chakraMode != lastSyncedMode) {
            needsSync = true;
        }

        if (needsSync) {
            try {
                // Safe reflection call to ModPackets.sendChakraUpdate
                Class<?> packets = Class.forName("com.example.shinobicore.network.ModPackets");
                java.lang.reflect.Method m = packets.getMethod("sendChakraUpdate", float.class, float.class, float.class, boolean.class, boolean.class);
                m.invoke(null, currentChakra, maxChakra, fatigue, chakraMode, exhausted);
            } catch (Exception ignored) {}
            
            lastSyncedCurrent = currentChakra;
            lastSyncedMode = chakraMode;
        }

        // 5. Mirror to legacy HUD/State via reflection (safe fallback)
        mirrorToLegacySystems();
    }

    private static void mirrorToLegacySystems() {
        try {
            Class<?> stateClass = Class.forName("com.example.shinobicore.client.ClientNinjaState");
            stateClass.getField("chakraMode").setBoolean(null, chakraMode);
        } catch (Exception ignored) {}

        try {
            Class<?> hudClass = Class.forName("com.example.shinobicore.client.hud.ChakraHudRenderer");
            hudClass.getField("currentChakra").setFloat(null, currentChakra);
            hudClass.getField("maxChakra").setFloat(null, maxChakra);
            hudClass.getField("exhausted").setBoolean(null, exhausted);
        } catch (Exception ignored) {}
    }

    public static void toggleChakraMode() {
        if (exhausted) {
            if (currentChakra >= maxChakra * 0.5f) {
                exhausted = false; // Recover from exhaustion if half full
            } else {
                return;
            }
        }
        chakraMode = !chakraMode;
    }

    public static float getCurrentChakra() { return currentChakra; }
    public static float getMaxChakra() { return maxChakra; }
    public static boolean isChakraMode() { return chakraMode; }
    public static boolean isExhausted() { return exhausted; }
    
    public static void setMeditating(boolean state) { meditating = state; }
}