// SHINOBICORE INDEPENDENT MOVEMENT LOGGER
// This logger does NOT modify any existing movement files.
// It reads state through public APIs only.
package com.example.shinobicore.util;

import net.fabricmc.loader.api.FabricLoader;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * Independent movement logger.
 * Writes to log_movement.txt in the game directory.
 * Does not modify any existing code - reads state via public APIs.
 */
public final class MovementLogger {
    private static final String FILE_NAME = "log_movement.txt";
    private static final SimpleDateFormat TIME_FMT = new SimpleDateFormat("HH:mm:ss.SSS");
    private static final Object LOCK = new Object();
    
    private static BufferedWriter writer;
    private static boolean initialized = false;
    private static boolean enabled = true;
    private static Path logPath;
    
    // Throttle control
    private static long lastLogTime = 0;
    private static final long MIN_INTERVAL_MS = 50;
    private static int tickCounter = 0;
    
    private MovementLogger() {}
    
    public static void init() {
        if (initialized) return;
        try {
            logPath = FabricLoader.getInstance().getGameDir().resolve(FILE_NAME);
            writer = Files.newBufferedWriter(logPath, StandardCharsets.UTF_8,
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND);
            initialized = true;
            writeRaw("============================================================");
            writeRaw("SHINOBICORE INDEPENDENT MOVEMENT LOGGER");
            writeRaw("Session started: " + new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date()));
            writeRaw("This logger does NOT modify any existing movement code.");
            writeRaw("============================================================");
        } catch (IOException e) {
            System.err.println("[MovementLogger] Failed to init: " + e.getMessage());
            enabled = false;
        }
    }
    
    public static void close() {
        if (!initialized) return;
        try {
            writeRaw("=== SESSION ENDED ===");
            writer.flush();
            writer.close();
        } catch (IOException ignored) {}
        initialized = false;
    }
    
    public static void setEnabled(boolean value) {
        enabled = value;
    }
    
    public static boolean isEnabled() {
        return enabled;
    }
    
    // ========================================
    // EVENT LOGGING (always logged)
    // ========================================
    
    public static void event(String category, String message) {
        if (!enabled || !initialized) return;
        String line = formatLine("EVENT", category, message);
        writeRaw(line);
    }
    
    public static void event(String category, String format, Object... args) {
        if (!enabled || !initialized) return;
        String message = (args != null && args.length > 0) ? String.format(format, args) : format;
        event(category, message);
    }
    
    // ========================================
    // STATE CHANGE LOGGING
    // ========================================
    
    public static void stateChange(String from, String to, String reason) {
        if (!enabled || !initialized) return;
        String line = formatLine("STATE", "PHASE", from + " -> " + to + " | reason: " + reason);
        writeRaw(line);
    }
    
    public static void stateChange(String from, String to) {
        stateChange(from, to, "unknown");
    }
    
    // ========================================
    // WARNING LOGGING (potential bugs)
    // ========================================
    
    public static void warn(String category, String message) {
        if (!enabled || !initialized) return;
        String line = formatLine("WARN", category, message);
        writeRaw(line);
    }
    
    public static void warn(String category, String format, Object... args) {
        if (!enabled || !initialized) return;
        String message = (args != null && args.length > 0) ? String.format(format, args) : format;
        warn(category, message);
    }
    
    // ========================================
    // ERROR LOGGING
    // ========================================
    
    public static void error(String category, String message) {
        if (!enabled || !initialized) return;
        String line = formatLine("ERROR", category, message);
        writeRaw(line);
    }
    
    // ========================================
    // TICK LOGGING (throttled)
    // ========================================
    
    public static void tick(String phase, double x, double y, double z, 
                           double vx, double vy, double vz, boolean onGround) {
        if (!enabled || !initialized) return;
        
        tickCounter++;
        
        boolean significantVelocity = Math.abs(vy) > 0.5 || Math.abs(vx) > 1.0 || Math.abs(vz) > 1.0;
        boolean shouldLog = (tickCounter % 10 == 0) || significantVelocity;
        
        if (!shouldLog) return;
        
        long now = System.currentTimeMillis();
        if (now - lastLogTime < MIN_INTERVAL_MS && !significantVelocity) return;
        lastLogTime = now;
        
        String msg = String.format("phase=%s pos=(%.1f, %.1f, %.1f) vel=(%.2f, %.2f, %.2f) ground=%b",
                phase, x, y, z, vx, vy, vz, onGround);
        String line = formatLine("TICK", "MOVE", msg);
        writeRaw(line);
    }
    
    // ========================================
    // VELOCITY/POSITION ANOMALY DETECTION
    // ========================================
    
    public static void velocityCheck(String source, double oldVy, double newVy) {
        if (!enabled || !initialized) return;
        double delta = Math.abs(newVy - oldVy);
        if (delta > 0.5) {
            warn("VELOCITY", String.format("LARGE VELOCITY CHANGE: source=%s oldVy=%.2f newVy=%.2f delta=%.2f",
                    source, oldVy, newVy, delta));
        }
    }
    
    public static void positionJump(String source, double oldY, double newY) {
        if (!enabled || !initialized) return;
        double delta = Math.abs(newY - oldY);
        if (delta > 1.0) {
            warn("POSITION", String.format("POSITION JUMP DETECTED: source=%s oldY=%.2f newY=%.2f delta=%.2f",
                    source, oldY, newY, delta));
        }
    }
    
    // ========================================
    // INTERNAL
    // ========================================
    
    private static String formatLine(String level, String category, String message) {
        String time = TIME_FMT.format(new Date());
        String thread = Thread.currentThread().getName();
        return String.format("[%s] [%-5s] [%-10s] [%-12s] %s", time, level, category, thread, message);
    }
    
    private static void writeRaw(String line) {
        synchronized (LOCK) {
            try {
                writer.write(line);
                writer.newLine();
                writer.flush();
            } catch (IOException ignored) {}
        }
    }
}