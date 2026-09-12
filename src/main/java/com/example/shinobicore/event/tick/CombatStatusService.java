package com.example.shinobicore.event.tick;

import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * P1-1 (ADR-012): эффекты боевого состояния.
 *
 * БЫЛО. В NinjaTickHandler в одном тике для одного игрока:
 *   1. медитация накладывала SLOWNESS(40, amp)
 *   2. щит защитной стойки накладывал SLOWNESS(25, 2)
 *   3. блок "если НЕ истощён" делал removeStatusEffect(SLOWNESS) и (WEAKNESS)
 * Пункт 3 выполнялся ПОСЛЕ 1 и 2 и снимал эффекты по ТИПУ, не различая источник.
 * Итог: медитация и блок работали без штрафной цены — эксплойт прокачки и баланса.
 *
 * СТАЛО. Управление по фронту (edge-triggered): эффекты накладываются при входе
 * в состояние и истекают сами по своей длительности. Никаких removeStatusEffect
 * "на всякий случай".
 */
public final class CombatStatusService {

    private CombatStatusService() {}

    /** Длительности подобраны так, чтобы эффект истекал сам через ~2 сек. */
    private static final int EXHAUSTION_DURATION_TICKS = 40;
    private static final int SHIELD_DURATION_TICKS     = 25;

    /**
     * Амплитуда замедления щита. Раньше была захардкожена как 2 в NinjaTickHandler;
     * сохранена без изменения, чтобы не менять баланс молча.
     * TODO(Спринт 7): заменить на CombatCfg.blockSlowAmplifier и привязать
     * к KenjutsuStance.getShieldSlow().
     */
    private static final int SHIELD_SLOW_AMPLIFIER = 2;

    private static final Map<UUID, Boolean> WAS_EXHAUSTED = new HashMap<>();

    public static void tick(MinecraftServer server, ServerPlayerEntity player) {
        if (player == null) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (data == null) return;
        UUID uid = player.getUuid();

        // --- 1. Щит защитной стойки (перенос из NinjaTickHandler без изменения логики) ---
        boolean shield = data.isKatanaDeflectHeld()
                && KenjutsuStance.fromId(data.getKatanaStanceId()) == KenjutsuStance.DEFENSIVE;
        if (shield) {
            player.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.SLOWNESS, SHIELD_DURATION_TICKS, SHIELD_SLOW_AMPLIFIER,
                    false, false, false));
        }

        // --- 2. Истощение: ТОЛЬКО по фронту входа ---
        boolean exhausted = data.isExhausted();
        Boolean was = WAS_EXHAUSTED.get(uid);
        if (exhausted && (was == null || !was)) {
            player.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.WEAKNESS, EXHAUSTION_DURATION_TICKS, 0, false, false, false));
            player.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.SLOWNESS, EXHAUSTION_DURATION_TICKS, 1, false, false, false));
        }
        WAS_EXHAUSTED.put(uid, exhausted);
    }

    /** H3-подобная очистка: вызывать на ServerPlayConnectionEvents.DISCONNECT. */
    public static void removePlayer(UUID uid) {
        if (uid == null) return;
        WAS_EXHAUSTED.remove(uid);
    }

    public static void clear() {
        WAS_EXHAUSTED.clear();
    }
}