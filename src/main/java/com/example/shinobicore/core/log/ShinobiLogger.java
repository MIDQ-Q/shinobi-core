package com.example.shinobicore.core.log;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Unified logging facade for ShinobiCore.
 * Supports module-based filtering and configurable log levels.
 */
public final class ShinobiLogger {
    private static final Logger CORE = LoggerFactory.getLogger("ShinobiCore");
    private static String currentLevel = "INFO";
    
    private ShinobiLogger() {}
    
    /**
     * Set the global log level.
     */
    public static void setLevel(String level) {
        currentLevel = level.toUpperCase();
        CORE.info("Log level set to: {}", currentLevel);
    }
    
    /**
     * Get the current log level.
     */
    public static String getLevel() {
        return currentLevel;
    }
    
    /**
     * Check if a log level is enabled.
     */
    public static boolean isLevelEnabled(String level) {
        int current = levelToInt(currentLevel);
        int target = levelToInt(level);
        return target >= current;
    }
    
    private static int levelToInt(String level) {
        return switch (level.toUpperCase()) {
            case "TRACE" -> 0;
            case "DEBUG" -> 1;
            case "INFO" -> 2;
            case "WARN" -> 3;
            case "ERROR" -> 4;
            default -> 2;
        };
    }
    
    // === Core logging ===
    
    public static void trace(String message) {
        if (isLevelEnabled("TRACE")) CORE.trace(message);
    }
    
    public static void debug(String message) {
        if (isLevelEnabled("DEBUG")) CORE.debug(message);
    }
    
    public static void info(String message) {
        CORE.info(message);
    }
    
    public static void warn(String message) {
        CORE.warn(message);
    }
    
    public static void error(String message, Throwable t) {
        if (t != null) CORE.error(message, t);
        else CORE.error(message);
    }
    
    // === Module-based logging ===
    
    public static void module(String moduleId, String message) {
        Logger moduleLogger = LoggerFactory.getLogger("ShinobiCore." + moduleId);
        moduleLogger.info(message);
    }
    
    public static void moduleDebug(String moduleId, String message) {
        if (isLevelEnabled("DEBUG")) {
            Logger moduleLogger = LoggerFactory.getLogger("ShinobiCore." + moduleId);
            moduleLogger.debug(message);
        }
    }
    
    public static void moduleError(String moduleId, String message, Throwable t) {
        Logger moduleLogger = LoggerFactory.getLogger("ShinobiCore." + moduleId);
        if (t != null) moduleLogger.error(message, t);
        else moduleLogger.error(message);
    }
    
    /**
     * Log an exception with context.
     */
    public static void exception(String context, String message, Throwable t) {
        CORE.error("[{}] {}", context, message, t);
    }
}