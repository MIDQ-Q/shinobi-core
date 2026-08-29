package com.example.shinobicore.stat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;

public interface IDojutsuComponent extends ComponentV3, AutoSyncedComponent {
    String getActiveDojutsu();
    boolean activateDojutsu(String dojutsuId);
    boolean deactivateDojutsu();
    int getActiveStage();
    void setActiveStage(int stage);
    int getUsage(String dojutsuId);
    void addUsage(String dojutsuId, int amount);
    float getStress(String dojutsuId);
    void addStress(String dojutsuId, float amount);
    void removeStress(String dojutsuId, float amount);
    boolean isBlinded();
    void resetAll();
}