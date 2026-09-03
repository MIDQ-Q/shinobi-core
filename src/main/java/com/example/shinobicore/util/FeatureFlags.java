package com.example.shinobicore.util;

/**
 * Feature flags for enabling/disabling subsystems.
 * All modules check these flags before operating.
 */
public final class FeatureFlags {
    private FeatureFlags() {}
    
    // Core systems
    public static boolean enableCore = true;
    public static boolean enableCommands = true;
    public static boolean enableDataLoading = true;
    
    // Jutsu system
    public static boolean enableJutsuCasting = true;
    public static boolean enableSkillTree = true;
    public static boolean enableAttunement = true;
    
    // Combat systems
    public static boolean enableGenjutsu = true;
    public static boolean enableSensory = true;
    public static boolean enableClans = true;
    
    // World modification
    public static boolean enableWorldModification = true;
    
    // Legacy systems (disabled for v3.0)
    public static boolean enableLegacyTaijutsu = false;
    public static boolean enableLegacyParkour = false;
    public static boolean enableLegacyHud = false;
    public static boolean enableWallWalk = false;
    public static boolean enableWorldgen = false;
    public static boolean enableClones = false;
    
    /**
     * Check if a feature is enabled.
     */
    public static boolean isEnabled(String featureName) {
        return switch (featureName) {
            case "core" -> enableCore;
            case "commands" -> enableCommands;
            case "data_loading" -> enableDataLoading;
            case "jutsu_casting" -> enableJutsuCasting;
            case "skill_tree" -> enableSkillTree;
            case "attunement" -> enableAttunement;
            case "genjutsu" -> enableGenjutsu;
            case "sensory" -> enableSensory;
            case "clans" -> enableClans;
            case "world_modification" -> enableWorldModification;
            default -> false;
        };
    }
}