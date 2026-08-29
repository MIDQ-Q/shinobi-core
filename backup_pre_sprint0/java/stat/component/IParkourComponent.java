package com.example.shinobicore.stat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;

public interface IParkourComponent extends ComponentV3, AutoSyncedComponent {
    NinjaPose getCurrentPose();
    void setCurrentPose(NinjaPose pose);
    
    int getJumpsLeft();
    void setJumpsLeft(int jumps);
    void resetJumps();
    
    int getDodgeCooldown();
    void setDodgeCooldown(int ticks);
    
    int getIframeTicks();
    void setIframeTicks(int ticks);
    boolean hasIframes();
}