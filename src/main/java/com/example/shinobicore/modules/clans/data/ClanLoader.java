package com.example.shinobicore.modules.clans.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

public final class ClanLoader {
    private static final Gson GSON = new GsonBuilder().create();
    private static int loadedCount = 0;

    public static void load() {
        ClanRegistry.clear();
        loadedCount = 0;

        try {
            Path clansDir = FabricLoader.getInstance().getConfigDir()
                .resolve("shinobicore").resolve("clans");

            if (!Files.exists(clansDir)) {
                Files.createDirectories(clansDir);
                ShinobiLogger.module("clans", "Created empty clans config dir: " + clansDir);
                return;
            }

            File[] jsonFiles = clansDir.toFile().listFiles((dir, name) -> name.endsWith(".json"));
            if (jsonFiles == null || jsonFiles.length == 0) {
                ShinobiLogger.module("clans", "No clan JSON files found in: " + clansDir);
                return;
            }

            for (File jsonFile : jsonFiles) {
                try (var is = new FileInputStream(jsonFile);
                     var reader = new InputStreamReader(is, StandardCharsets.UTF_8)) {
                    ClanDefinition clan = GSON.fromJson(reader, ClanDefinition.class);
                    if (clan == null) continue;
                    ClanRegistry.register(clan.sanitize());
                    loadedCount++;
                } catch (Exception e) {
                    ShinobiLogger.error("clans", "Failed to parse: " + jsonFile.getName(), e);
                }
            }

            ShinobiLogger.module("clans", "Loaded " + loadedCount + " clans from config dir");

        } catch (Exception e) {
            ShinobiLogger.error("clans", "Fatal error during clan loading", e);
        }
    }

    public static int getLoadedCount() { return loadedCount; }
}