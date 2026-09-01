package com.example.shinobicore.util;

/**
 * Feature flags for safe module toggling during refactoring.
 * Each subsystem can be disabled independently without breaking others.
 * Default: all enabled. Set to false to disable during testing.
 */
public final class FeatureFlags {
    private FeatureFlags() {}

    // === CORE SYSTEMS ===
    public static boolean chakraSystem = true;
    public static boolean progressionSystem = true;
    public static boolean clanSystem = true;
    public static boolean jutsuSystem = true;

    // === COMBAT ===
    public static boolean taijutsuCombat = true;
    public static boolean kenjutsuCombat = true;
    public static boolean shurikenCombat = true;
    public static boolean genjutsuSystem = true;

    // === MOVEMENT / PARKOUR ===
    public static boolean parkourSystem = true;
    public static boolean waterWalk = true;
    public static boolean wallRun = true;
    public static boolean slide = true;
    public static boolean dodge = true;
    public static boolean chargedJump = true;

    // === CLIENT VISUALS ===
    public static boolean hudRenderer = true;
    public static boolean particleEffects = true;
    public static boolean cameraSystem = true;

    // === NETWORK ===
    public static boolean packetValidation = true;
    public static boolean rateLimiting = true;

    // === DIAGNOSTICS ===
    public static boolean diagnosticCommands = true;

    /**
     * Check if a subsystem is enabled by name.
     */
    public static boolean isEnabled(String systemName) {
        return switch (systemName.toLowerCase()) {
            case "chakra" -> chakraSystem;
            case "progression" -> progressionSystem;
            case "clan" -> clanSystem;
            case "jutsu" -> jutsuSystem;
            case "taijutsu" -> taijutsuCombat;
            case "kenjutsu" -> kenjutsuCombat;
            case "shuriken" -> shurikenCombat;
            case "genjutsu" -> genjutsuSystem;
            case "parkour" -> parkourSystem;
            case "water_walk" -> waterWalk;
            case "wall_run" -> wallRun;
            case "slide" -> slide;
            case "dodge" -> dodge;
            case "charged_jump" -> chargedJump;
            case "hud" -> hudRenderer;
            case "particles" -> particleEffects;
            case "camera" -> cameraSystem;
            case "packet_validation" -> packetValidation;
            case "rate_limiting" -> rateLimiting;
            case "diagnostics" -> diagnosticCommands;
            default -> true;
        };
    }
}