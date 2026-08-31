// SHINOBICORE SPRINT A FILE
package com.example.shinobicore.mixin;

import com.example.shinobicore.jutsu.XpHookService;
import com.example.shinobicore.stat.component.StatType;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.item.Items;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
* Mixin to award XP when player deals damage.
* Injected at HEAD of LivingEntity.damage().
*/
@Mixin(LivingEntity.class)
public abstract class LivingEntityDamageXpMixin {

@Inject(method = "damage", at = @At("HEAD"))
private void shinobicore_awardCombatXp(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
LivingEntity self = (LivingEntity)(Object) this;

// Only process if attacker is a player
if (source.getAttacker() instanceof ServerPlayerEntity attacker) {
// Determine attack stat based on weapon
StatType attackStat = getAttackStat(attacker, source);

// Award XP
XpHookService.awardCombatXp(attacker, amount, attackStat);
}
}

/**
* Determine attack stat based on weapon and damage source.
*/
private StatType getAttackStat(ServerPlayerEntity attacker, DamageSource source) {
// Check weapon in main hand
ItemStack weapon = attacker.getMainHandStack();

// Swords -> KENJUTSU
if (weapon.isOf(Items.WOODEN_SWORD) ||
weapon.isOf(Items.STONE_SWORD) ||
weapon.isOf(Items.IRON_SWORD) ||
weapon.isOf(Items.GOLDEN_SWORD) ||
weapon.isOf(Items.DIAMOND_SWORD) ||
weapon.isOf(Items.NETHERITE_SWORD)) {
return StatType.KENJUTSU;
}

// Bows -> SHURIKEN
if (weapon.isOf(Items.BOW) ||
weapon.isOf(Items.CROSSBOW) ||
weapon.isOf(Items.TRIDENT)) {
return StatType.SHURIKEN;
}

// Default: unarmed -> TAIJUTSU
return StatType.TAIJUTSU;
}
}