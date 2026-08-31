package com.example.shinobicore.modules.jutsu.event;

import net.minecraft.server.network.ServerPlayerEntity;

public final class JutsuEvents {
    public record JutsuCastStartedEvent(ServerPlayerEntity caster, String jutsuId, int slot) {}
    public record JutsuCastFinishedEvent(ServerPlayerEntity caster, String jutsuId, boolean success) {}
    public record JutsuCastCancelledEvent(ServerPlayerEntity caster, String jutsuId, String reason) {}
    public record JutsuCooldownChangedEvent(ServerPlayerEntity player, String jutsuId, int remainingTicks) {}
    public record JutsuSlotChangedEvent(ServerPlayerEntity player, int slot, String jutsuId) {}
    
    private JutsuEvents() {}
}