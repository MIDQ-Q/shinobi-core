package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Отдельный логгер для техник.
 * Пишет в файл: config/shinobicore/jutsu_debug.log
 * Также дублирует в консоль через SLF4J.
 */
public class JutsuLogger {
    private static final Logger CONSOLE = LoggerFactory.getLogger("ShinobiCore-Jutsu");
    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS");
    private static Path logPath;
    private static boolean enabled = true;
    private static java.io.BufferedWriter bufferedWriter;

    /**
     * Инициализация логгера. Вызывать ОДИН РАЗ в ShinobiCore.onInitialize().
     */
    public static void init() {
        logPath = Path.of("config", "shinobicore", "jutsu_debug.log");
        try {
            Files.createDirectories(logPath.getParent());
            if (!Files.exists(logPath)) {
                Files.createFile(logPath);
                writeHeader();
            }
            CONSOLE.info("Jutsu debug log initialized: {}", logPath.toAbsolutePath());
        } catch (IOException e) {
            CONSOLE.error("Failed to create jutsu debug log: {}", e.getMessage());
            enabled = false;
        }
    }

    private static void writeHeader() {
        try (PrintWriter pw = new PrintWriter(new FileWriter(logPath.toFile(), true))) {
            pw.println("=== ShinobiCore Jutsu Debug Log ===");
            pw.println("Started: " + LocalDateTime.now().format(FMT));
            pw.println();
        } catch (IOException ignored) {}
    }

    /**
     * Логирование каста техники. Вызывается из JutsuCaster.cast().
     */
    public static void logCast(ServerPlayerEntity player, JutsuDefinition def,
                                NinjaPlayerData data, float damage, float cost) {
        if (!enabled) return;
        String msg = String.format(
                "[CAST] player=%s | jutsu=%s | type=%s | nature=%s | cost=%.1f | damage=%.2f | chakra=%.1f/%.1f | fatigue=%.1f",
                player.getName().getString(),
                def.id(),
                def.type(),
                def.hasNature() ? def.nature().getId() : "none",
                cost,
                damage,
                data.getCurrentChakra(),
                NinjaFormula.maxChakra(data),
                data.getFatigue()
        );
        write(msg);
    }

    /**
     * Логирование behavior'а. Вызывается из behaviors.
     */
    public static void logBehavior(String behaviorType, String message) {
        if (!enabled) return;
        write(String.format("[BEHAVIOR:%s] %s", behaviorType, message));
    }

    /**
     * Логирование снаряда. Вызывается из NinjaProjectileEntity.
     */
    public static void logProjectile(String event, double x, double y, double z, String details) {
        if (!enabled) return;
        write(String.format("[PROJECTILE:%s] pos=(%.2f, %.2f, %.2f) | %s", event, x, y, z, details));
    }

    /**
     * Логирование столкновения. Вызывается из NinjaProjectileEntity.
     */
    public static void logCollision(String type, String target, float damage) {
        if (!enabled) return;
        write(String.format("[COLLISION] type=%s | target=%s | damage=%.2f", type, target, damage));
    }

    /**
     * Логирование ошибки.
     */
    public static void logError(String context, Exception e) {
        if (!enabled) return;
        write(String.format("[ERROR:%s] %s", context, e.getMessage()));
        CONSOLE.error("[JutsuError:{}] {}", context, e.getMessage());
    }

    /**
     * Произвольное информационное сообщение.
     */
    public static void logInfo(String message) {
        if (!enabled) return;
        write(String.format("[INFO] %s", message));
    }

    private static void write(String message) {
        String timestamp = LocalDateTime.now().format(FMT);
        String line = timestamp + " " + message;

        // В консоль (debug уровень чтобы не засорять)
        CONSOLE.debug(line);

        // В файл
        try (PrintWriter pw = new PrintWriter(new FileWriter(logPath.toFile(), true))) {
            pw.println(line);
        } catch (IOException ignored) {
            // Тихо игнорируем ошибки записи
        }
    }

    /**
     * Включение/выключение логирования.
     */
    public static void setEnabled(boolean value) {
        enabled = value;
        CONSOLE.info("Jutsu debug logging {}", value ? "ENABLED" : "DISABLED");
    }
}