package com.example.shinobicore.modules.jutsu.view;

import com.example.shinobicore.modules.jutsu.cast.CastPhase;

public interface JutsuVisualView {
    boolean isCasting();
    float getCastProgress();
    CastPhase getCurrentPhase();
    String getCurrentJutsuId();
    boolean isCharging();
    boolean isQueued();
    String getQueuedJutsuId();
    
    String getSlotJutsuId(int slot);
    int getSelectedSlot();
    int getSlotCount();
    
    int getCooldownTicks(String jutsuId);
    int getMaxCooldownTicks(String jutsuId);
    float getCooldownProgress(String jutsuId);
}