package com.example.shinobicore.modules.combat.view;

public interface CombatVisualView {
    String getCurrentStance();
    boolean isBlocking();
    boolean isParrying();
    int getComboStep();
    boolean isSheathed();
    boolean isThrowing();
    float getBlockProgress();
    float getParryWindowProgress();
    String getWeaponClass();
}