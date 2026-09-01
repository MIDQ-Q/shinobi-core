package com.example.shinobicore.core.event;

import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.network.ServerPlayerEntity;

/**
 * Core lifecycle and gameplay events.
 * All events are simple records published through ShinobiEventBus.
 */
public final class ShinobiEvents {
    private ShinobiEvents() {}

    // === Lifecycle ===
    public record ModuleEnabledEvent(String moduleId) {}
    public record ModuleDisabledEvent(String moduleId, String reason) {}

    // === Chakra ===
    public record ChakraChangedEvent(PlayerEntity player, float oldVal, float newVal, float max) {}
    public record ChakraModeToggledEvent(PlayerEntity player, boolean enabled) {}
    public record ChakraDepletedEvent(PlayerEntity player) {}
    public record MeditationStartedEvent(PlayerEntity player) {}
    public record MeditationStoppedEvent(PlayerEntity player) {}

    // === Progression ===
    public record XpGainedEvent(ServerPlayerEntity player, int amount, String source) {}
    public record LevelChangedEvent(ServerPlayerEntity player, int oldLevel, int newLevel) {}
    public record SpGainedEvent(ServerPlayerEntity player, int amount) {}
    public record SpSpentEvent(ServerPlayerEntity player, int amount, String reason) {}

    // === Jutsu ===
    public record JutsuCastStartedEvent(ServerPlayerEntity player, String jutsuId) {}
    public record JutsuCastCompletedEvent(ServerPlayerEntity player, String jutsuId) {}
    public record JutsuCastInterruptedEvent(ServerPlayerEntity player, String jutsuId, String reason) {}
    public record JutsuLevelUpEvent(ServerPlayerEntity player, String jutsuId, int newLevel) {}

    // === Clan ===
    public record ClanSelectedEvent(ServerPlayerEntity player, String clanId) {}
    public record ClanChangedEvent(ServerPlayerEntity player, String oldClan, String newClan) {}

    // === Combat ===
    public record MeleeHitEvent(ServerPlayerEntity attacker, ServerPlayerEntity target,
                                 float damage, boolean crit) {}
    public record BlockActivatedEvent(ServerPlayerEntity player) {}
    public record ParrySuccessEvent(ServerPlayerEntity defender, PlayerEntity attacker) {}
    public record ParryFailEvent(ServerPlayerEntity player) {}

    // === Movement ===
    public record ParkourActionEvent(ServerPlayerEntity player, String actionId) {}

    // === Client-only (use ClientEventBus) ===
    public record ClientChakraSyncEvent(float current, float max, float fatigue, boolean exhausted) {}
    public record ClientStanceChangedEvent(String stanceId) {}
}