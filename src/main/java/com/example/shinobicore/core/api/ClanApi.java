package com.example.shinobicore.core.api;

import net.minecraft.entity.player.PlayerEntity;

public interface ClanApi {
    String getClanId(PlayerEntity player);
    boolean hasClan(PlayerEntity player);
    String getClanName(PlayerEntity player);
    String getClanColor(PlayerEntity player);

    float getCostMultiplier(PlayerEntity player, String jutsuId);
    float getStatBonus(PlayerEntity player, String statId);
    float getFatigueMultiplier(PlayerEntity player);
    boolean isClanJutsu(PlayerEntity player, String jutsuId);
    int getExtraAffinityCount(PlayerEntity player);

    void setClan(PlayerEntity player, String clanId);
    void clearClan(PlayerEntity player);
}