package com.example.shinobicore.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class ShinobiLogger {
    private static final Logger LOGGER = LoggerFactory.getLogger("ShinobiCore");
    
    private ShinobiLogger() {}

    public static void info(String msg, Object... args) { LOGGER.info(msg, args); }
    public static void warn(String msg, Object... args) { LOGGER.warn(msg, args); }
    public static void error(String msg, Object... args) { LOGGER.error(msg, args); }
    public static void debug(String msg, Object... args) { LOGGER.debug(msg, args); }
    public static void fatal(String msg, Object... args) { LOGGER.error("FATAL: " + msg, args); }
    public static void exception(String context, Exception e) { LOGGER.error("Exception in {}: {}", context, e.getMessage(), e); }

    public static void init() { info("Logger initialized"); }
    public static void close() { /* SLF4J doesn't need explicit close */ }
    public static void setLevel(Level level) { info("Log level set to: {}", level); }

    public enum Level { TRACE, DEBUG, INFO, WARN, ERROR, FATAL }
}