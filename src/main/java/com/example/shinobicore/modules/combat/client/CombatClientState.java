package com.example.shinobicore.modules.combat.client;

import com.example.shinobicore.modules.combat.common.Stance;

public final class CombatClientState {
    private static Stance currentStance = Stance.NONE;
    private static boolean isSheathed = false;
    private static boolean inCombatContext = false;

    public static Stance getCurrentStance() { return currentStance; }
    public static void setCurrentStance(Stance stance) { currentStance = stance; }
    
    public static boolean isSheathed() { return isSheathed; }
    public static void setSheathed(boolean sheathed) { isSheathed = sheathed; }
    
    public static boolean isInCombatContext() { return inCombatContext; }
    public static void setInCombatContext(boolean inContext) { inCombatContext = inContext; }
}