package com.example.shinobicore.progression;

import net.fabricmc.fabric.api.event.Event;
import net.fabricmc.fabric.api.event.EventFactory;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Event fired when a player casts a jutsu. Used by progression
 * system to track jutsu usage and grow stats.
 * HLD Section 10 (Progression System).
 */
public interface JutsuCastEvent {

    Event<JutsuCastEvent> EVENT = EventFactory.createArrayBacked(
        JutsuCastEvent.class,
        listeners -> (player, jutsuId, statType) -> {
            for (JutsuCastEvent listener : listeners) {
                listener.onJutsuCast(player, jutsuId, statType);
            }
        }
    );

    void onJutsuCast(ServerPlayerEntity player, String jutsuId, String statType);
}