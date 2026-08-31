package com.example.shinobicore.stat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;

public interface IChakraComponent extends ComponentV3, AutoSyncedComponent {
    float getCurrentChakra();
    float getMaxChakra();
    float getFatigue();
    boolean isChakraMode();
    void setCurrentChakra(float value);
    void setMaxChakra(float value);
    void setFatigue(float value);
    void setChakraMode(boolean v);
    void addFatigue(float amount);
    void removeFatigue(float amount);
    boolean isExhausted();
    float restoreChakra(float amount);
    boolean spendChakra(float amount);
    void resetToDefaults();

    // === MOVEMENT V3 ADDITIONS (Script 04) ===
    void setExhausted(boolean v);
    boolean isMeditating();
    void setMeditating(boolean v);
}