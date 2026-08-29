package com.example.shinobicore.stat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;

/**
 * Combat state component (Epic Fight sync target).
 * HLD: Section 1.1 (CombatComponent), Section 4
 */
public interface ICombatComponent extends ComponentV3, AutoSyncedComponent {

    int getComboStep();
    void setComboStep(int step);
    void incrementCombo();
    void resetCombo();

    long getLastAttackMs();
    void setLastAttackMs(long time);

    String getStanceId();
    void setStanceId(String stanceId);

    boolean isBlocking();
    void setBlocking(boolean blocking);

    int getGateState();
    void setGateState(int gate);
}