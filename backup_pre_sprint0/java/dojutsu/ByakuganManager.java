package com.example.shinobicore.dojutsu;

import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Box;

import java.util.List;

/**
 * Byakugan sensory: highlight living entities through walls (Glowing).
 * Server-side only. Orbit camera deferred to Sprint 7.
 * HLD: Section 7.2
 */
public final class ByakuganManager {

    public static final String ID = "byakugan";
    private static final int SCAN_RADIUS = 32;

    private ByakuganManager() {}

    /**
     * Server tick while byakugan active: apply Glowing to entities in radius.
     */
    public static void tick(ServerPlayerEntity player) {
        if (player.age % 40 != 0) return;

        Box box = player.getBoundingBox().expand(SCAN_RADIUS);
        List<LivingEntity> entities = player.getWorld().getEntitiesByClass(
            LivingEntity.class, box, e -> e != player);
        for (LivingEntity e : entities) {
            e.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, 60, 0));
        }
    }
}