package com.example.shinobicore.stat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;

public interface IChakraComponent extends ComponentV3, AutoSyncedComponent {
    float getCurrentChakra();
    float getMaxChakra();
    int getReserveLevel();
    float getFatigue();
    void setCurrentChakra(float value);
    void setMaxChakra(float value);
    void setReserveLevel(int level);
    void addFatigue(float amount);
    void removeFatigue(float amount);
    void setFatigue(float value);
    boolean isExhausted();
    float restoreChakra(float amount);
    boolean spendChakra(float amount);
    boolean isChakraMode();
    void setChakraMode(boolean v);
    void resetToDefaults();
}