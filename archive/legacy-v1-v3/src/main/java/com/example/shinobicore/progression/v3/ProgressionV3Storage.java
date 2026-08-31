// SHINOBICORE:SPRINT15:FILE
package com.example.shinobicore.progression.v3;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.minecraft.server.MinecraftServer;
import net.minecraft.util.WorldSavePath;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * SPRINT 15 persistent storage for progression.
 *
 * Location:
 * <world>/shinobicore/progression/<uuid>.json
 */
public final class ProgressionV3Storage {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    private ProgressionV3Storage() {}

    public static Path getDirectory(MinecraftServer server) {
        return server.getSavePath(WorldSavePath.ROOT)
                .resolve("shinobicore")
                .resolve("progression");
    }

    public static Path getFile(MinecraftServer server, UUID uuid) {
        return getDirectory(server).resolve(uuid.toString() + ".json");
    }

    public static ProgressionV3.Data load(MinecraftServer server, UUID uuid) {
        Path path = getFile(server, uuid);

        if (!Files.exists(path)) {
            return null;
        }

        try {
            String json = new String(Files.readAllBytes(path), StandardCharsets.UTF_8);
            ProgressionV3.Data data = GSON.fromJson(json, ProgressionV3.Data.class);
            return normalize(data);
        } catch (Exception e) {
            try {
                Path bad = path.resolveSibling(uuid.toString() + ".json.bad");
                Files.move(path, bad, StandardCopyOption.REPLACE_EXISTING);
            } catch (Exception ignored) {
            }

            return null;
        }
    }

    public static void save(MinecraftServer server, UUID uuid, ProgressionV3.Data data) {
        try {
            Path dir = getDirectory(server);
            Files.createDirectories(dir);

            Path path = getFile(server, uuid);
            String json = GSON.toJson(normalize(data));

            Files.write(path, json.getBytes(StandardCharsets.UTF_8));
        } catch (Exception ignored) {
        }
    }

    public static void delete(MinecraftServer server, UUID uuid) {
        try {
            Files.deleteIfExists(getFile(server, uuid));
        } catch (Exception ignored) {
        }
    }

    private static ProgressionV3.Data normalize(ProgressionV3.Data data) {
        if (data == null) {
            data = new ProgressionV3.Data();
        }

        if (data.statLevels == null) {
            data.statLevels = new ConcurrentHashMap<>();
        } else if (!(data.statLevels instanceof ConcurrentHashMap)) {
            data.statLevels = new ConcurrentHashMap<>(data.statLevels);
        }

        if (data.statXp == null) {
            data.statXp = new ConcurrentHashMap<>();
        } else if (!(data.statXp instanceof ConcurrentHashMap)) {
            data.statXp = new ConcurrentHashMap<>(data.statXp);
        }

        return data;
    }
}