package com.example.shinobicore.client.combat.frenzy;

import com.example.shinobicore.client.movement.AnimClock;
import com.example.shinobicore.network.ModPackets;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.client.MinecraftClient;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;

/**
 * Combat Pack v1 (1.1.4): клиентское состояние «боевого ража».
 *
 * Сервер считает убийства и уровни (FrenzyTracker) и шлёт FRENZY_SYNC;
 * клиент здесь хранит уровень и отвечает за:
 *   - визуальное замедление времени (AnimClock -> JSON-анимации);
 *   - красный оверлей + виньетка (FrenzyVisualRenderer);
 *   - сердцебиение (частота растёт с уровнем);
 *   - звуки входа/выхода из ража.
 *
 * ВАЖНО: клиент не может поднять уровень сам — только из пакета сервера.
 */
public final class FrenzyClientState {

    private FrenzyClientState() {}

    /** Замедление анимаций по уровням (0..4). */
    public static final float[] TIME_SCALES = { 1.0f, 0.85f, 0.70f, 0.55f, 0.40f };
    /** Альфа красного оверлея по уровням. */
    public static final int[] OVERLAY_ALPHA = { 0, 16, 30, 48, 66 };

    private static int level = 0;
    private static boolean active = false;
    private static long remainingMs = 0;
    private static int killCount = 0;
    private static float damageMult = 1f;
    private static float timeScale = 1f;
    private static long lastHeartbeatMs = 0;
    private static int prevLevel = 0;

    public static void register() {
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.FRENZY_SYNC_ID, (client, handler, buf, responseSender) -> {
            final byte lvl = buf.readByte();
            final float mult = buf.readFloat();
            final long rem = buf.readLong();
            final int kills = buf.readInt();
            final boolean act = buf.readBoolean();
            client.execute(() -> onSync(lvl, mult, rem, kills, act));
        });
        ClientTickEvents.END_CLIENT_TICK.register(FrenzyClientState::tick);
        ClientPlayConnectionEvents.DISCONNECT.register((handler, client) -> reset());
        HudRenderCallback.EVENT.register(FrenzyVisualRenderer::render);
    }

    private static void onSync(byte lvl, float mult, long rem, int kills, boolean act) {
        int newLevel = Math.max(0, Math.min(4, lvl));
        if (newLevel > level) {
            // вход/рост уровня — звук и всплеск сердцебиения
            MinecraftClient client = MinecraftClient.getInstance();
            if (client.player != null) {
                client.player.playSound(SoundEvents.ENTITY_PLAYER_LEVELUP, SoundCategory.PLAYERS,
                        0.55f, 0.6f + newLevel * 0.08f);
            }
        }
        if (newLevel == 0 && level > 0) {
            MinecraftClient client = MinecraftClient.getInstance();
            if (client.player != null) {
                client.player.playSound(SoundEvents.BLOCK_WOOL_FALL, SoundCategory.PLAYERS, 0.4f, 0.7f);
            }
        }
        prevLevel = level;
        level = newLevel;
        damageMult = mult;
        remainingMs = rem;
        killCount = kills;
        active = act && level > 0;
    }

    private static void tick(MinecraftClient client) {
        if (client.player == null) { reset(); return; }

        if (active) {
            remainingMs -= 50;
            if (remainingMs <= 0) {
                active = false;
                level = 0;
            }
        }
        // плавное замедление/ускорение времени
        float target = active ? TIME_SCALES[level] : 1.0f;
        timeScale += (target - timeScale) * 0.10f;
        if (Math.abs(timeScale - target) < 0.002f) timeScale = target;

        // сердцебиение: 80 + 12 BPM за уровень, слышно с уровня 2
        if (active && level >= 2) {
            float bpm = 80f + level * 12f;
            long interval = (long) (60000f / bpm);
            long now = System.currentTimeMillis();
            if (now - lastHeartbeatMs >= interval) {
                lastHeartbeatMs = now;
                client.player.playSound(SoundEvents.ENTITY_WARDEN_HEARTBEAT, SoundCategory.PLAYERS,
                        0.55f, 0.9f + level * 0.06f);
            }
        }
    }

    public static float getTimeScale() { return timeScale; }
    public static int getLevel() { return level; }
    public static boolean isActive() { return active; }
    public static float getDamageMult() { return damageMult; }
    public static int getKillCount() { return killCount; }
    public static long getRemainingMs() { return Math.max(0, remainingMs); }

    /** Альфа оверлея с пульсацией на уровнях 3+. */
    public static int getOverlayAlpha() {
        if (!active || level <= 0) return 0;
        int base = OVERLAY_ALPHA[Math.min(level, OVERLAY_ALPHA.length - 1)];
        if (level >= 3) {
            double pulse = 0.85 + 0.15 * Math.sin(System.currentTimeMillis() / 240.0);
            base = (int) (base * pulse);
        }
        return Math.max(0, Math.min(255, base));
    }

    public static void reset() {
        level = 0; prevLevel = 0; active = false; remainingMs = 0;
        killCount = 0; damageMult = 1f; timeScale = 1f; lastHeartbeatMs = 0;
        AnimClock.reset();
    }
}