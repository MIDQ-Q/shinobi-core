package com.example.shinobicore.core.log;
import net.fabricmc.loader.api.FabricLoader;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
public final class ShinobiLogger {
    private static final Logger SLF4J = LoggerFactory.getLogger("ShinobiCore");
    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static Path logDir;
    private static final int MAX_ROTATION = 3;
    private ShinobiLogger() {}
    public static void init() {
        try {
            logDir = FabricLoader.getInstance().getGameDir().resolve("logs").resolve("shinobicore");
            Files.createDirectories(logDir);
        } catch (Throwable t) {
            SLF4J.error("Failed to init log dir", t);
        }
    }
    public static void core(String message) {
        SLF4J.info("[CORE] {}", message);
        // File logging disabled for performance
    }
    public static void module(String moduleId, String message) {
        SLF4J.info("[{}] {}", moduleId, message);
        // File logging disabled for performance
    }
    public static void error(String moduleId, String message, Throwable t) {
        if (t == null) SLF4J.error("[{}] {}", moduleId, message);
        else SLF4J.error("[{}] {}", moduleId, message, t);
        String text = "[" + moduleId + "] ERROR: " + message;
        if (t != null) text += " -> " + t.getClass().getSimpleName() + ": " + t.getMessage();
        appendRotated(moduleId, text);
    }
    public static void info(String message) { SLF4J.info(message); }
    private static void appendRotated(String type, String line) {
        if (logDir == null) return;
        try {
            rotate(type);
            Path current = logDir.resolve(type + "-1.log");
            String stamp = LocalDateTime.now().format(FMT);
            Files.writeString(current, "[" + stamp + "] " + line + System.lineSeparator(),
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException ignored) {}
    }
    private static void rotate(String type) throws IOException {
        for (int i = MAX_ROTATION; i >= 1; i--) {
            Path p = logDir.resolve(type + "-" + i + ".log");
            if (i == MAX_ROTATION) {
                Files.deleteIfExists(p);
            } else {
                Path next = logDir.resolve(type + "-" + (i + 1) + ".log");
                if (Files.exists(p)) Files.move(p, next, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            }
        }
    }
}