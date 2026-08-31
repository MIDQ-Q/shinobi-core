package com.example.shinobicore.core.api;

import net.minecraft.entity.player.PlayerEntity;
import java.util.Map;

public interface StatsApi {
    int getStatLevel(PlayerEntity player, String statId);
    float getStatValue(PlayerEntity player, String statId);
    void addStatXp(PlayerEntity player, String statId, float xp);
    Map<String, Integer> getAllStats(PlayerEntity player);
}