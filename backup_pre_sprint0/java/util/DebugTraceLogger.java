package com.example.shinobicore.util;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.loader.api.FabricLoader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.text.SimpleDateFormat;
import java.util.Date;

public final class DebugTraceLogger {
    private static final String FILE_NAME = "debug_trace.log";
    private static BufferedWriter writer;
    private static boolean initialized = false;
    private static final SimpleDateFormat SDF = new SimpleDateFormat("HH:mm:ss.SSS");
    private static final Object LOCK = new Object();

    private DebugTraceLogger() {}

    public static void init() {
        if (initialized) return;
        initialized = true;
        Path logDir = FabricLoader.getInstance().getConfigDir().resolve("shinobicore");
        try {
            Files.createDirectories(logDir);
            Path logFile = logDir.resolve(FILE_NAME);
            writer = Files.newBufferedWriter(logFile, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE);
            writeRaw("=== SHINOBICORE DEBUG TRACE SESSION STARTED ===");
            ShinobiCore.LOGGER.info("DebugTraceLogger initialized. Writing to {}", logFile.toAbsolutePath());
        } catch (IOException e) {
            ShinobiCore.LOGGER.error("Failed to initialize DebugTraceLogger", e);
        }
    }

    public static void close() {
        if (!initialized) return;
        initialized = false;
        writeRaw("=== SESSION ENDED ===");
        if (writer != null) {
            try { writer.flush(); writer.close(); } catch (IOException e) {}
        }
    }

    private static void writeRaw(String message) {
        if (writer != null) {
            synchronized (LOCK) {
                try { writer.write(message); writer.newLine(); writer.flush(); } catch (IOException e) {}
            }
        }
    }

    public static void trace(String category, String message, Object... args) {
        if (!initialized) return;
        String time = SDF.format(new Date());
        String thread = Thread.currentThread().getName();
        String formattedMsg = (args != null && args.length > 0) ? String.format(message, args) : message;
        String logLine = String.format("[%s] [%-10s] [%-8s] %s", time, thread, category, formattedMsg);
        writeRaw(logLine);
    }

    public static void action(String actionName, String details) {
        trace("ACTION", "DO [%s] | %s", actionName, details);
    }
    
    public static void check(String checkName, boolean result, String details) {
        trace("LOGIC", "CHECK [%s] => %b | %s", checkName, result, details);
    }
}