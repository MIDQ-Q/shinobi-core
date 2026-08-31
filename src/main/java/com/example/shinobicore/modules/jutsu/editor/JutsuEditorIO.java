package com.example.shinobicore.modules.jutsu.editor;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import net.fabricmc.loader.api.FabricLoader;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

public final class JutsuEditorIO {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    private JutsuEditorIO() {}

    private static Path getJutsuDir() {
        return FabricLoader.getInstance().getConfigDir()
            .resolve("shinobicore").resolve("jutsu");
    }

    public static void save(JutsuEditorData data) {
        try {
            Path dir = getJutsuDir();
            Files.createDirectories(dir);
            JsonObject root = new JsonObject();
            root.addProperty("id", data.id);
            root.addProperty("name", data.name);
            root.addProperty("element", data.element);
            root.addProperty("behavior", data.behaviorType);
            root.addProperty("baseCost", data.baseCost);
            root.addProperty("cooldownTicks", data.cooldownTicks);
            root.addProperty("prepareTicks", 0);
            root.addProperty("chargeTicks", 0);
            root.addProperty("releaseTicks", data.castTimeTicks);
            root.addProperty("maxChargeMultiplier", 1.0);
            JsonObject reqs = new JsonObject();
            reqs.addProperty("minPlayerLevel", data.minPlayerLevel);
            root.add("requirements", reqs);
            JsonObject bd = new JsonObject();
            bd.addProperty("damage", data.damage);
            bd.addProperty("range", data.range);
            bd.addProperty("radius", data.radius);
            root.add("behaviorData", bd);
            String fileName = data.id.replace(":", "_").replace("/", "_") + ".json";
            Path filePath = dir.resolve(fileName);
            Files.writeString(filePath, GSON.toJson(root));
            ShinobiLogger.module("jutsu_editor", "Saved: " + data.id);
        } catch (IOException e) {
            ShinobiLogger.error("jutsu_editor", "Save failed: " + e.getMessage(), e);
        }
    }

    public static void delete(String jutsuId) {
        try {
            Path dir = getJutsuDir();
            String fileName = jutsuId.replace(":", "_").replace("/", "_") + ".json";
            Path filePath = dir.resolve(fileName);
            if (Files.exists(filePath)) {
                Files.delete(filePath);
                ShinobiLogger.module("jutsu_editor", "Deleted: " + jutsuId);
            }
        } catch (IOException e) {
            ShinobiLogger.error("jutsu_editor", "Delete failed: " + e.getMessage(), e);
        }
    }
}