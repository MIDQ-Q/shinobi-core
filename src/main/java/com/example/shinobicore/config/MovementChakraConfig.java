// SHINOBICORE:SPRINT1:FILE
package com.example.shinobicore.config;

import com.example.shinobicore.util.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * SPRINT 1 independent movement/chakra config.
 *
 * File:
 * config/shinobicore/movement_chakra.json
 */
public final class MovementChakraConfig {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static MovementChakraConfig instance;

    public ChakraSection chakra = new ChakraSection();
    public MovementSection movement = new MovementSection();
    public LoggingSection logging = new LoggingSection();

    public MovementChakraConfig() {}

    public static synchronized MovementChakraConfig getInstance() {
        if (instance == null) {
            instance = new MovementChakraConfig();
        }

        return instance;
    }

    public static Path getPath() {
        return FabricLoader.getInstance()
                .getConfigDir()
                .resolve("shinobicore")
                .resolve("movement_chakra.json");
    }

    public static synchronized void load() {
        Path path = getPath();

        try {
            if (Files.exists(path)) {
                String json = new String(Files.readAllBytes(path), StandardCharsets.UTF_8);
                MovementChakraConfig parsed = GSON.fromJson(json, MovementChakraConfig.class);

                if (parsed == null) {
                    parsed = new MovementChakraConfig();
                }

                parsed.normalize();
                instance = parsed;
                ShinobiLogger.info("[SPRINT1] Loaded movement_chakra.json");
            } else {
                instance = new MovementChakraConfig();
                save();
                ShinobiLogger.info("[SPRINT1] Created default movement_chakra.json");
            }
        } catch (Exception e) {
            ShinobiLogger.error("[SPRINT1] Failed to load movement_chakra.json: " + e.getMessage());
            instance = new MovementChakraConfig();

            try {
                save();
            } catch (Exception ignored) {
            }
        }
    }

    public static synchronized void save() {
        try {
            Path path = getPath();

            if (path.getParent() != null) {
                Files.createDirectories(path.getParent());
            }

            String json = GSON.toJson(getInstance());
            Files.write(path, json.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            ShinobiLogger.error("[SPRINT1] Failed to save movement_chakra.json: " + e.getMessage());
        }
    }

    public static synchronized void reload() {
        instance = null;
        load();
        ShinobiLogger.info("[SPRINT1] movement_chakra.json reloaded");
    }

    private void normalize() {
        if (chakra == null) chakra = new ChakraSection();
        if (movement == null) movement = new MovementSection();
        if (logging == null) logging = new LoggingSection();
    }

    public static class ChakraSection {
        public float baseMaxChakra = 2000.0f;
        public float chakraRegenPerSec = 2.0f;
        public float chakraModeDrainPerSec = 3.0f;
        public float waterWalkDrainPerTick = 0.05f;
        public float wallWalkDrainPerTick = 0.075f;
        public float meditationRegenMultiplier = 3.0f;
    }

    public static class MovementSection {
        public boolean waterWalk = true;
        public boolean wallRun = true;
        public boolean slide = true;
        public boolean crawl = true;
        public boolean roll = true;
        public boolean dodge = true;
        public boolean chargedJump = true;
        public boolean doubleJump = true;
        public boolean edgeGrab = true;
        public boolean meditation = true;
    }

    public static class LoggingSection {
        public boolean chakra = false;
        public boolean movement = false;
        public boolean serverMirror = false;
    }
}