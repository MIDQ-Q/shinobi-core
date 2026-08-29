package com.example.shinobicore.progression;

import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.IDojutsuComponent;
import com.example.shinobicore.stat.component.IJutsuComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.entity.attribute.EntityAttributeInstance;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Applies body-level effects and syncs components once per second.
 * - Vitality: max HP 20 -> 400, regen up to +75%
 * - Speed: movement speed +100% at lvl 10
 * - Jump: JUMP_BOOST scaling with level (+50% at lvl 10)
 * - Reserve: chakra reserve 200 -> 2000
 * - Control & Endurance: handled in JutsuCaster
 */
public final class ProgressionEffects {

    private ProgressionEffects() {}

    public static void init() {
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            if (server.getTicks() % 20 != 0) return;
            for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
                apply(p);
            }
        });
    }

    private static void apply(ServerPlayerEntity p) {
        IStatsComponent stats = NinjaComponents.getStats(p);
        IChakraComponent chakra = NinjaComponents.getChakra(p);
        if (stats == null || chakra == null) return;

        int vit = stats.getBodyLevelVitality();
        int res = stats.getBodyLevelReserve();
        int spd = stats.getBodyLevelSpeed();
        int jmp = stats.getBodyLevelJump();

        // Reserve: 200 at lvl 0 -> 2000 at lvl 100 (18 per level)
        chakra.setMaxChakra(200.0f + res * 18.0f);

        // Chakra regen: base 2.0, +75% at vitality 100, +1 if meditation passive
        float regen = 2.0f * (1.0f + vit * 0.0075f);
        if (stats.hasPassive("meditation")) regen += 1.0f;
        chakra.restoreChakra(regen);

        // Max HP: 20 at lvl 0 -> 400 at lvl 100 (3.8 per level)
        EntityAttributeInstance hpAttr = p.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
        if (hpAttr != null) {
            hpAttr.setBaseValue(20.0 + vit * 3.8);
        }

        // HP regen (vitality-based): heal 0.5 HP/sec base, up to +75%
        if (p.getHealth() < p.getMaxHealth()) {
            p.heal(0.5f * (1.0f + vit * 0.0075f));
        }

        // Speed: 0.1 base, +100% at lvl 10 (0.01 per level)
        EntityAttributeInstance spdAttr = p.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (spdAttr != null) {
            spdAttr.setBaseValue(0.1 + spd * 0.01);
        }

        // Jump: +50% max at lvl 10 via JUMP_BOOST (amplifier = level/2 - 1)
        if (jmp > 0) {
            int amplifier = Math.max(0, jmp / 2 - 1);
            p.addStatusEffect(new StatusEffectInstance(
                StatusEffects.JUMP_BOOST, 40, amplifier, true, false, false));
        }

        // Sync to client for HUD
        NinjaComponents.CHAKRA.sync(p, chakra);
        NinjaComponents.STATS.sync(p, stats);
        IJutsuComponent jutsu = NinjaComponents.getJutsu(p);
        if (jutsu != null) NinjaComponents.JUTSU.sync(p, jutsu);
        IDojutsuComponent doj = NinjaComponents.getDojutsu(p);
        if (doj != null) NinjaComponents.DOJUTSU.sync(p, doj);
    }
}