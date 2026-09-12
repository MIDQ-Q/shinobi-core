package com.example.shinobicore.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.entity.event.v1.ServerLivingEntityEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;

/**
 * Combat Pack v1 (1.1.4): «боевой раж» — серия убийств усиливает игрока.
 *
 * Механика (по плану дорожной карты):
 *   - убийство в пределах окна (combat.frenzyWindowMs, 3 с) растит счётчик;
 *   - уровни 1..4 за 1/2/3/5 убийств; бонус урона +10/+20/+35/+50%;
 *   - клиент получает FRENZY_SYNC и рисует замедление/оверлей/сердцебиение
 *     (см. FrenzyClientState) — серверный тикрейт НЕ меняется, мультиплеер
 *     не страдает;
 *   - множитель урона применяется СЕРВЕРОМ в CombatPacketHandlers
 *     (тай-дзюцу и катана); клиент не может его подделать;
 *   - сброс: смерть игрока, выход из мира, истечение окна.
 *
 * Античит: не более 10 убийств за 5 секунд (взрыв толпы так не «накрутить»
 * сверх порога — лишние игнорируются), два убийства в один тик считаются
 * одним для цепочки.
 */
public final class FrenzyTracker {

    private FrenzyTracker() {}

    /** Убийств для уровня 1..4. */
    private static final int[] KILL_THRESHOLDS = { 1, 2, 3, 5 };
    private static final int MAX_LEVEL = 4;

    private static final class State {
        int killCount;
        int level;
        long windowStartMs;
        long expiryMs;
        long rateStartMs;
        int rateCount;
        long lastKillGameTick = -100L;
        long lastSyncTick = -100L;
    }

    private static final Map<UUID, State> STATES = new HashMap<>();
    private static long currentGameTick = 0L;

    public static void register() {
        ServerLivingEntityEvents.AFTER_DEATH.register((entity, source) -> {
            if (entity instanceof ServerPlayerEntity victim) {
                reset(victim);
                return;
            }
            if (source == null) return;
            if (source.getAttacker() instanceof ServerPlayerEntity killer && killer != entity) {
                onKill(killer, entity);
            }
        });
        ServerTickEvents.END_SERVER_TICK.register(FrenzyTracker::tick);
        ShinobiCore.LOGGER.info("[Frenzy] Combat Pack v1: tracker registered");
    }

    private static ModConfig.Combat cfg() { return ModConfig.instance.combat; }

    public static void onKill(ServerPlayerEntity killer, LivingEntity victim) {
        ModConfig.Combat c = cfg();
        if (c == null || !c.frenzyEnabled) return;
        if (killer == null || victim == null) return;
        // саммоны и призывы игрока не считаются (убийца — сам игрок, это уже проверено)

        long now = System.currentTimeMillis();
        State s = STATES.computeIfAbsent(killer.getUuid(), k -> new State());

        // античит: частота убийств
        if (now - s.rateStartMs > 5000L) { s.rateStartMs = now; s.rateCount = 0; }
        s.rateCount++;
        if (s.rateCount > 10) {
            ShinobiCore.LOGGER.warn("[Frenzy] kill rate limit for {}", killer.getName().getString());
            return;
        }
        // два убийства в один игровой тик (взрыв) — одно для цепочки
        if (s.lastKillGameTick == currentGameTick && s.killCount > 0) {
            return;
        }
        s.lastKillGameTick = currentGameTick;

        long window = c.frenzyWindowMs > 0 ? c.frenzyWindowMs : 3000L;
        if (s.killCount == 0 || now - s.windowStartMs > window) {
            s.killCount = 0;
            s.windowStartMs = now;
        }
        s.killCount++;

        int lvl = 0;
        for (int i = 0; i < KILL_THRESHOLDS.length; i++) {
            if (s.killCount >= KILL_THRESHOLDS[i]) lvl = i + 1;
        }
        s.level = Math.min(lvl, MAX_LEVEL);
        long durationMs = 3000L + (s.level >= 3 ? 1000L : 0L) + (s.level >= 4 ? 1000L : 0L);
        s.expiryMs = now + durationMs;
        sync(killer);
    }

    /** Множитель урона для CombatPacketHandlers (1.0, если раж неактивен). */
    public static float damageMultiplier(ServerPlayerEntity player) {
        if (player == null) return 1.0f;
        ModConfig.Combat c = cfg();
        if (c == null || !c.frenzyEnabled) return 1.0f;
        State s = STATES.get(player.getUuid());
        if (s == null || s.level <= 0) return 1.0f;
        if (System.currentTimeMillis() > s.expiryMs) return 1.0f;
        float bonus;
        switch (Math.min(s.level, MAX_LEVEL)) {
            case 1: bonus = c.frenzyDamage1; break;
            case 2: bonus = c.frenzyDamage2; break;
            case 3: bonus = c.frenzyDamage3; break;
            case 4: bonus = c.frenzyDamage4; break;
            default: bonus = 0f;
        }
        return 1.0f + Math.max(0f, bonus);
    }

    public static int level(ServerPlayerEntity player) {
        State s = player == null ? null : STATES.get(player.getUuid());
        if (s == null || System.currentTimeMillis() > s.expiryMs) return 0;
        return s.level;
    }

    public static void sync(ServerPlayerEntity player) {
        if (player == null) return;
        State s = STATES.get(player.getUuid());
        long now = System.currentTimeMillis();
        int lvl = 0; float mult = 1.0f; long rem = 0L; int kills = 0; boolean act = false;
        if (s != null) {
            act = s.level > 0 && now <= s.expiryMs;
            lvl = act ? s.level : 0;
            rem = act ? Math.max(0L, s.expiryMs - now) : 0L;
            kills = s.killCount;
            mult = act ? damageMultiplier(player) : 1.0f;
        }
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeByte(lvl);
        buf.writeFloat(mult);
        buf.writeLong(rem);
        buf.writeInt(kills);
        buf.writeBoolean(act);
        ServerPlayNetworking.send(player, ModPackets.FRENZY_SYNC_ID, buf);
    }

    public static void reset(ServerPlayerEntity player) {
        if (player == null) return;
        State s = STATES.get(player.getUuid());
        if (s != null) { s.level = 0; s.killCount = 0; s.expiryMs = 0L; }
        sync(player);
    }

    public static void removePlayer(UUID uid) {
        if (uid != null) STATES.remove(uid);
    }

    private static void tick(MinecraftServer server) {
        currentGameTick++;
        if (STATES.isEmpty()) return;
        long now = System.currentTimeMillis();
        Iterator<Map.Entry<UUID, State>> it = STATES.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<UUID, State> e = it.next();
            State s = e.getValue();
            ServerPlayerEntity p = server.getPlayerManager().getPlayer(e.getKey());
            if (p == null) {
                // игрок вышел — чистим (дополнительно к DISCONNECT-хуку)
                if (s.level == 0 && now - s.windowStartMs > 60000L) it.remove();
                continue;
            }
            if (s.level > 0 && now > s.expiryMs) {
                s.level = 0;
                s.killCount = 0;
                sync(p);
            } else if (s.level > 0 && currentGameTick - s.lastSyncTick >= 20L) {
                // периодическая синхронизация остатка (клиентский таймер не уползает)
                s.lastSyncTick = currentGameTick;
                sync(p);
            }
        }
    }
}