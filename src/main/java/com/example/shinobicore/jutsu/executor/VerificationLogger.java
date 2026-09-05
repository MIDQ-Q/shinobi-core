package com.example.shinobicore.jutsu.executor;

import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;

import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class VerificationLogger {
    private static final Path LOG_FILE = FabricLoader.getInstance().getGameDir().resolve("verification_results.txt");
    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static boolean enabled = true;

    public static void log(String category, String message) {
        if (!enabled) return;
        String ts = LocalDateTime.now().format(FMT);
        try (PrintWriter pw = new PrintWriter(Files.newBufferedWriter(LOG_FILE, StandardOpenOption.CREATE, StandardOpenOption.APPEND))) {
            pw.println(String.format("[%s] [%s] %s", ts, category, message));
        } catch (IOException ignored) {}
    }
    public static void logCast(LivingEntity caster, String jutsuId, String activationType) {
        log("CAST", String.format("Caster: %s | Jutsu: %s | Activation: %s",
            caster.getName().getString(), jutsuId, activationType));
    }
    public static void logHit(LivingEntity caster, LivingEntity target, String effectType, float damage) {
        log("HIT", String.format("Caster: %s | Target: %s | Effect: %s | Damage: %.1f",
            caster.getName().getString(), target.getName().getString(), effectType, damage));
    }
    public static void logProperty(String jutsuId, String propertyId, String details) {
        log("PROPERTY", String.format("Jutsu: %s | Property: %s | %s", jutsuId, propertyId, details));
    }
    public static void logEffect(String jutsuId, String effectType, String subtype, String details) {
        log("EFFECT", String.format("Jutsu: %s | Type: %s | Subtype: %s | %s", jutsuId, effectType, subtype, details));
    }
    public static void logActivation(String jutsuId, String activationType, String status) {
        log("ACTIVATION", String.format("Jutsu: %s | Type: %s | Status: %s", jutsuId, activationType, status));
    }
    public static void logProgression(LivingEntity player, String jutsuId, int level, int uses) {
        log("PROGRESSION", String.format("Player: %s | Jutsu: %s | Level: %d | Uses: %d",
            player.getName().getString(), jutsuId, level, uses));
    }
    public static void logError(String category, String message) { log("ERROR", String.format("[%s] %s", category, message)); }
    public static void setEnabled(boolean e) { enabled = e; }
}