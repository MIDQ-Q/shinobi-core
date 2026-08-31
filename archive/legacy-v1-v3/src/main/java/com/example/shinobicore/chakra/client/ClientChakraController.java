// SHINOBICORE MOVEMENT V3 FILE
package com.example.shinobicore.chakra.client;

import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.util.ShinobiConstants;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

/**
 * Client-authoritative chakra controller.
 * The client owns current chakra, spending, regen, chakra mode, meditation.
 * The server only mirrors and validates (see ServerChakraMirror).
 *
 * Sync rules:
 * - Send packet when change exceeds syncMinDelta
 * - Send on mode toggle, exhaustion change, meditation toggle
 * - Do NOT send every tick without changes
 */
public final class ClientChakraController {

    // === Core state ===
    private static float currentChakra = ShinobiConstants.BASE_MAX_CHAKRA;
    private static float maxChakra = ShinobiConstants.BASE_MAX_CHAKRA;
    private static float fatigue = 0.0f;
    private static boolean chakraModeActive = false;
    private static boolean exhausted = false;
    private static boolean meditating = false;

    // === Timing ===
    private static int regenDelayTicks = 0;
    private static int lastSpendTick = 0;
    private static int clientTick = 0;
    private static int exhaustionExitTicks = 0;

    // === Sync tracking ===
    private static boolean dirty = false;
    private static float lastSentCurrent = 0.0f;
    private static float lastSentFatigue = 0.0f;
    private static boolean lastSentMode = false;
    private static boolean lastSentExhausted = false;
    private static boolean lastSentMeditating = false;
    private static int sequenceNumber = 0;

    // === Registration ===
    private static boolean registered = false;

    private ClientChakraController() {}

    public static void register() {
        if (registered) return;
        registered = true;

        ClientTickEvents.END_CLIENT_TICK.register(ClientChakraController::tickClient);
        ClientPlayConnectionEvents.DISCONNECT.register((handler, client) -> resetLocalState());

        ShinobiLogger.info("ClientChakraController registered");
    }

    // ============================================================
    // MAIN TICK
    // ============================================================

    private static void tickClient(MinecraftClient client) {
        clientTick++;
        ClientPlayerEntity player = client.player;

        if (player == null) {
            resetLocalState();
            return;
        }

        if (player.isDead()) {
            if (chakraModeActive) setChakraMode(false);
            if (meditating) setMeditating(false);
            return;
        }

        // Config access
        ShinobiCoreConfig cfg = ShinobiCoreConfig.getInstance();
        ShinobiCoreConfig.ChakraClientSection chakraCfg = cfg.chakraClient;
        ShinobiCoreConfig.MeditationSection medCfg = cfg.meditation;

        // Update effective max chakra
        updateEffectiveMaxChakra();

        // === Meditation logic ===
        if (meditating) {
            float regenMult = medCfg.regenMultiplier;
            float fatigueDecayMult = medCfg.fatigueDecayMultiplier;

            float regen = chakraCfg.regenPerSecond / 20.0f * regenMult;
            float fatigueDecay = 2.0f / 20.0f * fatigueDecayMult;

            currentChakra = Math.min(maxChakra, currentChakra + regen);
            fatigue = Math.max(0.0f, fatigue - fatigueDecay);

            // Break meditation on movement or damage
            if (isPlayerMoving(player)) {
                setMeditating(false);
            }
        }
        // === Chakra mode drain ===
        else if (chakraModeActive) {
            float drainPerTick = ShinobiConstants.CHAKRA_MODE_DRAIN_PER_SEC / 20.0f;
            if (currentChakra >= drainPerTick) {
                currentChakra -= drainPerTick;
                regenDelayTicks = chakraCfg.regenDelayTicks;
                markDirty();
            } else {
                // Not enough chakra - disable mode
                setChakraMode(false);
                if (chakraCfg.fatigue.enabled) {
                    exhausted = true;
                    exhaustionExitTicks = 200; // 10 seconds
                }
            }
        }
        // === Normal regen ===
        else {
            if (regenDelayTicks > 0) {
                regenDelayTicks--;
            } else if (!exhausted) {
                float regen = chakraCfg.regenPerSecond / 20.0f;
                currentChakra = Math.min(maxChakra, currentChakra + regen);
                markDirty();
            }

            // Fatigue decay
            if (chakraCfg.fatigue.enabled && fatigue > 0) {
                float decay = chakraCfg.fatigue.decayPerSecond / 20.0f;
                fatigue = Math.max(0.0f, fatigue - decay);
                markDirty();
            }
        }

        // === Exhaustion management ===
        if (exhausted) {
            exhaustionExitTicks--;
            if (exhaustionExitTicks <= 0 && fatigue < chakraCfg.exhaustionExitThreshold) {
                exhausted = false;
                markDirty();
            }
        }

        // === Clamp values ===
        currentChakra = Math.max(0.0f, Math.min(currentChakra, maxChakra));
        fatigue = Math.max(0.0f, Math.min(fatigue, 100.0f));

        // === Check if sync needed ===
        sendDirtyIfNeeded(chakraCfg);
    }

    // ============================================================
    // CHAKRA MODE
    // ============================================================

    public static void toggleChakraMode() {
        if (chakraModeActive) {
            setChakraMode(false);
        } else {
            if (canActivateChakraMode()) {
                setChakraMode(true);
            }
        }
    }

    public static void setChakraMode(boolean active) {
        if (chakraModeActive == active) return;
        chakraModeActive = active;
        markDirty();
        ShinobiLogger.debug("Chakra mode: %s", active ? "ON" : "OFF");
    }

    public static boolean canActivateChakraMode() {
        ShinobiCoreConfig.ChakraClientSection cfg = ShinobiCoreConfig.getInstance().chakraClient;

        if (exhausted) return false;
        if (currentChakra < cfg.modeActivationMinChakra) return false;
        if (cfg.fatigue.enabled && fatigue >= cfg.fatigue.hardThreshold) return false;
        return true;
    }

    // ============================================================
    // SPEND / RESTORE
    // ============================================================

    public static boolean spendChakra(float amount) {
        if (amount <= 0) return true;
        if (currentChakra < amount) return false;
        currentChakra -= amount;
        lastSpendTick = clientTick;
        regenDelayTicks = ShinobiCoreConfig.getInstance().chakraClient.regenDelayTicks;
        markDirty();
        return true;
    }

    public static float restoreChakra(float amount) {
        if (amount <= 0) return 0;
        float old = currentChakra;
        currentChakra = Math.min(maxChakra, currentChakra + amount);
        markDirty();
        return currentChakra - old;
    }

    // ============================================================
    // FATIGUE
    // ============================================================

    public static void addFatigue(float amount) {
        if (amount <= 0) return;
        ShinobiCoreConfig.ChakraClientSection cfg = ShinobiCoreConfig.getInstance().chakraClient;
        if (!cfg.fatigue.enabled) return;
        fatigue = Math.min(100.0f, fatigue + amount);
        if (fatigue >= cfg.exhaustionThreshold && !exhausted) {
            exhausted = true;
            exhaustionExitTicks = 200;
        }
        markDirty();
    }

    public static void decayFatigue(float amount) {
        if (amount <= 0) return;
        fatigue = Math.max(0.0f, fatigue - amount);
        markDirty();
    }

    // ============================================================
    // MEDITATION
    // ============================================================

    public static void setMeditating(boolean active) {
        if (meditating == active) return;
        meditating = active;
        if (active && chakraModeActive) {
            setChakraMode(false); // Meditation replaces chakra mode
        }
        markDirty();
        ShinobiLogger.debug("Meditation: %s", active ? "ON" : "OFF");
    }

    // ============================================================
    // GETTERS
    // ============================================================

    public static float getCurrentChakra() { return currentChakra; }
    public static float getMaxChakra() { return maxChakra; }
    public static float getFatigue() { return fatigue; }
    public static boolean isChakraModeActive() { return chakraModeActive; }
    public static boolean isExhausted() { return exhausted; }
    public static boolean isMeditating() { return meditating; }
    public static int getSequenceNumber() { return sequenceNumber; }

    public static float getEffectiveMaxChakra() {
        return maxChakra;
    }

    // ============================================================
    // ADMIN / SYNC
    // ============================================================

    public static void applyAdminSet(float newCurrent, float newMax, float newFatigue,
                                       boolean newMode, boolean newExhausted) {
        currentChakra = Math.max(0, Math.min(newCurrent, newMax));
        maxChakra = newMax;
        fatigue = Math.max(0, Math.min(newFatigue, 100));
        chakraModeActive = newMode;
        exhausted = newExhausted;
        markDirty();
        ShinobiLogger.info("Admin chakra set applied");
    }

    public static void onInitialServerSync(float serverCurrent, float serverMax, float serverFatigue,
                                              boolean serverMode, boolean serverExhausted, boolean serverMeditating) {
        currentChakra = serverCurrent;
        maxChakra = serverMax;
        fatigue = serverFatigue;
        chakraModeActive = serverMode;
        exhausted = serverExhausted;
        meditating = serverMeditating;
        markDirty();
        ShinobiLogger.info("Initial server sync applied: current=%.0f max=%.0f", serverCurrent, serverMax);
    }

    // ============================================================
    // SYNC LOGIC
    // ============================================================

    private static void markDirty() {
        dirty = true;
    }

    private static void sendDirtyIfNeeded(ShinobiCoreConfig.ChakraClientSection cfg) {
        if (!dirty) return;

        boolean modeChanged = chakraModeActive != lastSentMode;
        boolean exhaustedChanged = exhausted != lastSentExhausted;
        boolean meditatingChanged = meditating != lastSentMeditating;
        float currentDelta = Math.abs(currentChakra - lastSentCurrent);
        float fatigueDelta = Math.abs(fatigue - lastSentFatigue);

        boolean shouldSend = modeChanged || exhaustedChanged || meditatingChanged
                || currentDelta >= cfg.syncMinDelta
                || fatigueDelta >= cfg.fatigueSyncMinDelta;

        if (shouldSend) {
            sequenceNumber++;
            // Send packet to server
            net.minecraft.network.PacketByteBuf buf =
                net.fabricmc.fabric.api.networking.v1.PacketByteBufs.create();
            buf.writeVarInt(sequenceNumber);
            buf.writeFloat(currentChakra);
            buf.writeFloat(fatigue);
            buf.writeBoolean(chakraModeActive);
            buf.writeBoolean(exhausted);
            buf.writeBoolean(meditating);

            net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking.send(
                com.example.shinobicore.network.ModPackets.CHAKRA_CLIENT_STATE, buf);

            lastSentCurrent = currentChakra;
            lastSentFatigue = fatigue;
            lastSentMode = chakraModeActive;
            lastSentExhausted = exhausted;
            lastSentMeditating = meditating;
            dirty = false;
        }
    }

    // ============================================================
    // HELPERS
    // ============================================================

    private static void updateEffectiveMaxChakra() {
        ShinobiCoreConfig.ChakraClientSection cfg = ShinobiCoreConfig.getInstance().chakraClient;
        maxChakra = cfg.baseMaxChakra;
        // Future: add clan bonuses, stat bonuses here
    }

    private static boolean isPlayerMoving(ClientPlayerEntity player) {
        return Math.abs(player.getVelocity().x) > 0.01
                || Math.abs(player.getVelocity().z) > 0.01
                || player.input.movementForward != 0
                || player.input.movementSideways != 0;
    }

    private static void resetLocalState() {
        currentChakra = ShinobiConstants.BASE_MAX_CHAKRA;
        maxChakra = ShinobiConstants.BASE_MAX_CHAKRA;
        fatigue = 0.0f;
        chakraModeActive = false;
        exhausted = false;
        meditating = false;
        regenDelayTicks = 0;
        lastSpendTick = 0;
        clientTick = 0;
        exhaustionExitTicks = 0;
        dirty = false;
        lastSentCurrent = currentChakra;
        lastSentFatigue = fatigue;
        lastSentMode = false;
        lastSentExhausted = false;
        lastSentMeditating = false;
        sequenceNumber = 0;
    }
}