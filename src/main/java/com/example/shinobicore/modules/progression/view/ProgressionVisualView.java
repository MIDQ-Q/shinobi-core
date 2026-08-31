package com.example.shinobicore.modules.progression.view;

public interface ProgressionVisualView {
    int getPlayerLevel();
    int getCurrentXp();
    int getXpToNextLevel();
    int getAvailableSp();
    float getProgressToNextLevel();
    int getStatLevel(String statId);
    int getBodyStatLevel(String bodyStatId);
    int getJutsuLevel(String jutsuId);
    boolean isNodeUnlocked(String nodeId);
    boolean isElementUnlocked(String elementId);
    float getAttunementProgress(String elementId);
    int getReputation(String factionId);
}