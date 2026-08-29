package com.example.shinobicore.progression;

import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Helper to fire JutsuCastEvent from any jutsu behavior.
 * Safe to call - does nothing if player is not a ServerPlayerEntity.
 */
public final class JutsuCastNotifier {

    private JutsuCastNotifier() {}

    /**
     * Notify that a jutsu was cast. Called from behaviors.
     * @param player the caster
     * @param jutsuId jutsu identifier (e.g. "fireball")
     * @param statType related stat: "ninjutsu", "genjutsu", "taijutsu",
     *                 "bukijutsu", or "chakraControl"
     */
    public static void fire(ServerPlayerEntity player, String jutsuId, String statType) {
        if (player == null) return;
        JutsuCastEvent.EVENT.invoker().onJutsuCast(player, jutsuId, statType);
    }
}