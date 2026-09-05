package com.example.shinobicore.util;

public final class FeatureFlags {
    private FeatureFlags() {}
    
    public static boolean enableCore = true;
    public static boolean enableCommands = true;
    public static boolean enableDataLoading = true;
    public static boolean enableJutsuCasting = true;
    public static boolean enableSkillTree = true;
    public static boolean enableAttunement = true;
    public static boolean enableGenjutsu = true;
    public static boolean enableSensory = true;
    public static boolean enableClans = true;
    public static boolean enableWorldModification = true;
    public static boolean enableCuriosIntegration = true;
    
    // Legacy flags (disabled)
    public static boolean enableLegacyTaijutsu = false;
    public static boolean enableLegacyParkour = false;
    public static boolean enableLegacyHud = false;
}