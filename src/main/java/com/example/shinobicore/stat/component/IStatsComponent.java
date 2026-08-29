package com.example.shinobicore.stat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;
import java.util.Set;

public interface IStatsComponent extends ComponentV3, AutoSyncedComponent {
    int getStatLevel(StatType type);
    void setStatLevel(StatType type, int level);
    int addStatLevel(StatType type, int amount);
    int getStatXp(StatType type);
    boolean addXp(StatType type, int amount);
    void setStatXp(StatType type, int xp);
    int getSkillPoints();
    int getSp();
    void addSp(int amount);
    void setSkillPoints(int points);
    void addSkillPoints(int amount);
    boolean spendSkillPoints(int amount);
    int getBodyLevelHP();
    void setBodyLevelHP(int level);
    int getBodyLevelSpeed();
    void setBodyLevelSpeed(int level);
    int getBodyLevelJump();
    void setBodyLevelJump(int level);
    int getBodyLevelVitality();
    void setBodyLevelVitality(int level);
    int getBodyLevelReserve();
    void setBodyLevelReserve(int level);
    int getBodyLevelEndurance();
    void setBodyLevelEndurance(int level);
    Set<String> getUnlockedPassives();
    boolean unlockPassive(String passiveId);
    boolean hasPassive(String passiveId);
    void removePassive(String passiveId);
    int getXpForNextLevel(StatType type);
    float getProgressToNextLevel(StatType type);
    void resetToDefaults();
    // SPRINT A: New methods for stat bonuses
    float getInsightXpMultiplier();
    float getPhysicalDamageBonus();
    float getSpiritualChakraBonus();
    float getFocusCostReduction();
    float getWillpowerFatigueReduction();
    // Level validation: newLevel must be <= oldLevel + 1
    boolean trySetStatLevel(StatType type, int newLevel);
    boolean tryLevelUp(StatType type);
}