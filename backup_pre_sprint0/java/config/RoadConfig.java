package com.example.shinobicore.config;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;
import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * S8-08: Road generation configuration.
 * Allows disabling roads entirely or tweaking generation parameters.
 */
public class RoadConfig {
    public boolean enabled = true;
    public int maxRoadLengthChunks = 32;
    public int bridgeMaxWidth = 8; // >8 blocks = bypass (Variant C)
    public float slopeCost = 5.0f;
    public float waterCost = 20.0f;
    public float structureAvoidCost = 50.0f;
    public int lanternRadiusChunks = 5; // Lanterns only within this radius from village exit
    public boolean generateFallback = true;

    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    public static RoadConfig instance = new RoadConfig();

    public static Path path() {
        return FabricLoader.getInstance().getConfigDir()
            .resolve("shinobicore").resolve("roads.json");
    }

    public static void load() {
        try {
            Path p = path();
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                instance = new RoadConfig();
                save();
            } else {
                try (FileReader reader = new FileReader(p.toFile())) {
                    RoadConfig loaded = GSON.fromJson(reader, RoadConfig.class);
                    if (loaded != null) instance = loaded;
                }
            }
            ShinobiCore.LOGGER.info("[ROADS] Config loaded: enabled={}, bridgeMax={}", 
                instance.enabled, instance.bridgeMaxWidth);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[ROADS] Failed to load config, using defaults", e);
            instance = new RoadConfig();
        }
    }

    public static void save() {
        try (FileWriter writer = new FileWriter(path().toFile())) {
            GSON.toJson(instance, writer);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[ROADS] Failed to save config", e);
        }
    }
}