package com.example.shinobicore.api.chakra;

import net.minecraft.entity.player.PlayerEntity;

public interface ChakraApi {
    double getCurrent(PlayerEntity player);
    double getMax(PlayerEntity player);
    boolean isChakraModeActive(PlayerEntity player);
    boolean isExhausted(PlayerEntity player);
    boolean trySpend(PlayerEntity player, double amount);
    void regenerate(PlayerEntity player, double amount);
    void toggleChakraMode(PlayerEntity player);
}