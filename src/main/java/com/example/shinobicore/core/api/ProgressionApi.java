package com.example.shinobicore.core.api;

import net.minecraft.server.network.ServerPlayerEntity;

public interface ProgressionApi {
    int getPlayerLevel(ServerPlayerEntity player);
    int getCurrentXp(ServerPlayerEntity player);
    int getXpToNextLevel(ServerPlayerEntity player);
    int getAvailableSp(ServerPlayerEntity player);

    void addXp(ServerPlayerEntity player, int amount, String source);
    void addSp(ServerPlayerEntity player, int amount);
    boolean spendSp(ServerPlayerEntity player, int amount, String reason);

    int getJutsuLevel(ServerPlayerEntity player, String jutsuId);
    int getJutsuUses(ServerPlayerEntity player, String jutsuId);
    void addJutsuUse(ServerPlayerEntity player, String jutsuId);

    boolean isNodeUnlocked(ServerPlayerEntity player, String nodeId);
    boolean unlockNode(ServerPlayerEntity player, String nodeId);

    float getAttunementProgress(ServerPlayerEntity player, String elementId);
    boolean isElementUnlocked(ServerPlayerEntity player, String elementId);
    int getUnlockedElementCount(ServerPlayerEntity player);
}