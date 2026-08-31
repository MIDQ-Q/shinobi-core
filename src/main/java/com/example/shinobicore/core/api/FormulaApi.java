package com.example.shinobicore.core.api;

import net.minecraft.entity.player.PlayerEntity;

public interface FormulaApi {
    float calcMaxChakra(PlayerEntity player);
    float calcJutsuCost(PlayerEntity player, String jutsuId);
    float calcMeleeDamage(PlayerEntity player, float baseDamage);
    float calcRangedDamage(PlayerEntity player, float baseDamage);
    float calcFatigueGain(PlayerEntity player, float baseStrain);
    float calcRegenRate(PlayerEntity player);
    float calcMovementSpeed(PlayerEntity player);
    float calcJumpHeight(PlayerEntity player);
}