package com.example.shinobicore.core.api;

import net.minecraft.entity.player.PlayerEntity;

public interface ChakraApi {
    float getCurrent(PlayerEntity player);
    float getMax(PlayerEntity player);
    float getFatigue(PlayerEntity player);
    boolean isExhausted(PlayerEntity player);
    boolean isChakraModeActive(PlayerEntity player);
    boolean isMeditating(PlayerEntity player);
    float getReserved(PlayerEntity player);

    boolean trySpend(PlayerEntity player, float amount);
    void add(PlayerEntity player, float amount);
    void setCurrent(PlayerEntity player, float value);
    void setMax(PlayerEntity player, float value);
    void addFatigue(PlayerEntity player, float amount);
    void setChakraMode(PlayerEntity player, boolean active);
    void setMeditating(PlayerEntity player, boolean meditating);
    void resetToDefaults(PlayerEntity player);
}