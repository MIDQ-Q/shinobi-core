// SHINOBICORE:SPRINT0:FILE
package com.example.shinobicore.config;

/**
 * SPRINT 0 safe feature flags.
 *
 * These flags are intended to allow safe staged enable/disable of systems
 * during migration to version 3.0.
 *
 * This file is created only if missing. Existing file is not overwritten.
 */
public final class FeatureFlags {
    private FeatureFlags() {}

    public static boolean movementV3 = true;
    public static boolean chakraV3 = true;
    public static boolean progression = true;
    public static boolean combatV3 = false;

    public static boolean waterWalk = true;
    public static boolean wallRun = true;
    public static boolean slide = true;
    public static boolean crawl = true;
    public static boolean roll = true;
    public static boolean dodge = true;
    public static boolean chargedJump = true;
    public static boolean doubleJump = true;
    public static boolean edgeGrab = true;
    public static boolean meditation = true;

    public static boolean debugMovement = true;
    public static boolean debugChakra = false;
    public static boolean debugServerMirror = false;
    public static boolean chakraCommands = true;
    public static boolean chakraConfig = true;
    public static boolean serverChakraMirror = true;
}