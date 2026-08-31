package com.example.shinobicore.modules.progression.component;

import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import java.util.Map;
import java.util.Set;

public interface ProgressionComponent extends ComponentV3 {
    int getPlayerLevel();
    void setPlayerLevel(int level);
    int getCurrentXp();
    void addXp(int amount);
    void subtractXp(int amount);
    int getAvailableSp();
    void addSp(int amount);
    void spendSp(int amount);

    Set<String> getUnlockedNodes();
    boolean isNodeUnlocked(String nodeId);
    void unlockNode(String nodeId);

    Set<String> getUnlockedElements();
    boolean isElementUnlocked(String elementId);
    void unlockElement(String elementId);
    int getUnlockedElementCount();

    int getStatLevel(String statId);
    void setStatLevel(String statId, int level);
    Map<String, Integer> getAllStats();

    int getBodyStatLevel(String bodyStatId);
    void setBodyStatLevel(String bodyStatId, int level);
    Map<String, Integer> getAllBodyStats();

    float getStatXp(String statId);
    void addStatXp(String statId, float amount);

    int getJutsuLevel(String jutsuId);
    void setJutsuLevel(String jutsuId, int level);
    int getJutsuUses(String jutsuId);
    void addJutsuUse(String jutsuId);
    float getJutsuXp(String jutsuId);
    void addJutsuXp(String jutsuId, float amount);
    void setJutsuXp(String jutsuId, float xp);

    float getAttunementProgress(String elementId);
    void setAttunementProgress(String elementId, float progress);

    int getReputation(String factionId);
    void setReputation(String factionId, int value);
    Map<String, Integer> getAllReputation();
}