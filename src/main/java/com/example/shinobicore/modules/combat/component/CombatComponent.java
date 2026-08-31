package com.example.shinobicore.modules.combat.component;

import com.example.shinobicore.modules.combat.common.Stance;
import dev.onyxstudios.cca.api.v3.component.Component;

public interface CombatComponent extends Component {
    Stance getStance();
    void setStance(Stance stance);
    boolean isBlocking();
    void setBlocking(boolean blocking);
    boolean isParrying();
    void setParrying(boolean parrying);
    int getComboStep();
    void setComboStep(int step);
    void resetCombo();
    boolean isSheathed();
    void setSheathed(boolean sheathed);
    long getParryFailRecoveryUntil();
    void setParryFailRecoveryUntil(long timestampMs);
    long getComboExpireAtMs();
    void setComboExpireAtMs(long timestampMs);
}