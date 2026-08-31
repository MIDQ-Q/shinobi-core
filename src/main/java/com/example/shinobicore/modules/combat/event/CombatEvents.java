package com.example.shinobicore.modules.combat.event;

import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;

public final class CombatEvents {
    private CombatEvents() {}

    public record AttackEvent(ServerPlayerEntity attacker, Entity target, float totalDamage, int comboStep) {}
    public record HitEvent(ServerPlayerEntity attacker, LivingEntity target, float damage) {}
    public record BlockedEvent(ServerPlayerEntity blocker, Entity attacker, float reducedDamage) {}
    public record ParriedEvent(ServerPlayerEntity parrier, Entity attacker, boolean reflected) {}
    public record KickEvent(ServerPlayerEntity kicker, Entity target, float damage) {}
    public record StanceChangedEvent(ServerPlayerEntity player, String oldStance, String newStance) {}
    public record ComboChangedEvent(ServerPlayerEntity player, int oldStep, int newStep, String weaponClass) {}
    public record ThrowableThrownEvent(ServerPlayerEntity thrower, Entity projectile, String weaponId) {}
    public record WeaponSheathedEvent(ServerPlayerEntity player, boolean sheathed, String itemId) {}
    public record WeaponDrawnEvent(ServerPlayerEntity player, String itemId) {}
    public record ProjectileDeflectedEvent(ServerPlayerEntity defender, Entity projectile) {}
}