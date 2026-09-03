package com.example.shinobicore.config;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

/**
 * Central configuration manager.
 * Loads all config sections from a single JSON file.
 * Supports hot-reload via /shinobicore config reload.
 */
public final class ConfigManager {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static final Map<String, ConfigSection> SECTIONS = new LinkedHashMap<>();
    private static boolean loaded = false;

    private ConfigManager() {}

    public static void registerSection(ConfigSection section) {
        SECTIONS.put(section.id(), section);
        ShinobiLogger.module("config", "Registered config section: " + section.id());
    }

    public static Path getConfigPath() {
        return FabricLoader.getInstance().getConfigDir()
                .resolve("shinobicore").resolve("shinobicore.json");
    }

    public static void load() {
        Path path = getConfigPath();
        try {
            if (!Files.exists(path)) {
                Files.createDirectories(path.getParent());
                save();
                ShinobiLogger.module("config", "Created default config at: " + path);
            } else {
                try (Reader reader = new FileReader(path.toFile())) {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> root = GSON.fromJson(reader, Map.class);
                    if (root != null) {
                        for (Map.Entry<String, ConfigSection> entry : SECTIONS.entrySet()) {
                            Object sectionData = root.get(entry.getKey());
                            if (sectionData instanceof Map) {
                                @SuppressWarnings("unchecked")
                                Map<String, Object> data = (Map<String, Object>) sectionData;
                                entry.getValue().load(data);
                            }
                        }
                    }
                }
                save(); // Write back with any new defaults
            }
            loaded = true;
            ShinobiLogger.module("config", "Config loaded successfully from: " + path);
        } catch (Exception e) {
            ShinobiLogger.exception("config", "Failed to load config, using defaults", e);
            for (ConfigSection section : SECTIONS.values()) {
                section.resetToDefaults();
            }
            loaded = true;
        }
    }

    public static void save() {
        Path path = getConfigPath();
        try {
            Files.createDirectories(path.getParent());
            Map<String, Object> root = new LinkedHashMap<>();
            for (Map.Entry<String, ConfigSection> entry : SECTIONS.entrySet()) {
                root.put(entry.getKey(), entry.getValue().save());
            }
            try (Writer writer = new FileWriter(path.toFile())) {
                GSON.toJson(root, writer);
            }
        } catch (Exception e) {
            ShinobiLogger.exception("config", "Failed to save config", e);
        }
    }

    public static void reload() {
        loaded = false;
        load();
        ShinobiLogger.module("config", "Config reloaded.");
    }

    @SuppressWarnings("unchecked")
    public static <T extends ConfigSection> T getSection(Class<T> type) {
        for (ConfigSection section : SECTIONS.values()) {
            if (type.isInstance(section)) return (T) section;
        }
        return null;
    }

    public static boolean isLoaded() { return loaded; }

    public static List<String> validateAll() {
        List<String> warnings = new ArrayList<>();
        for (ConfigSection section : SECTIONS.values()) {
            warnings.addAll(section.validate());
        }
        return warnings;
    }
}