package com.example.shinobicore.modules.progression.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class ProgressionDataLoader {
    private static final String TREE_PATH = "/data/shinobicore/progression/tree/";
    private static final String ATTUNE_PATH = "/data/shinobicore/progression/attunement/";
    private static final String[] TREE_FILES = {
        "general.json", "fire.json", "water.json", "wind.json",
        "lightning.json", "earth.json", "special.json"
    };

    private ProgressionDataLoader() {}

    public static void loadTree() {
        TreeNodeRegistry.clear();
        int loaded = 0;
        for (String fileName : TREE_FILES) {
            String fullPath = TREE_PATH + fileName;
            try (InputStream is = ProgressionDataLoader.class.getResourceAsStream(fullPath)) {
                if (is == null) {
                    ShinobiLogger.module("progression", "Tree file not found: " + fullPath);
                    continue;
                }
                JsonElement root = JsonParser.parseReader(
                    new InputStreamReader(is, StandardCharsets.UTF_8));
                if (root.isJsonArray()) {
                    for (JsonElement el : root.getAsJsonArray()) {
                        try {
                            TreeNodeRegistry.register(parseTreeNode(el.getAsJsonObject()));
                            loaded++;
                        } catch (Exception e) {
                            ShinobiLogger.error("progression",
                                "Failed to parse node in " + fileName, e);
                        }
                    }
                }
            } catch (Exception e) {
                ShinobiLogger.error("progression", "Failed to read: " + fullPath, e);
            }
        }
        ShinobiLogger.module("progression", "Loaded " + loaded + " tree nodes");
    }

    public static void loadAttunement() {
        AttunementRegistry.clear();
        int loaded = 0;
        String fullPath = ATTUNE_PATH + "elements.json";
        try (InputStream is = ProgressionDataLoader.class.getResourceAsStream(fullPath)) {
            if (is == null) {
                ShinobiLogger.module("progression", "Attunement file not found: " + fullPath);
                return;
            }
            JsonElement root = JsonParser.parseReader(
                new InputStreamReader(is, StandardCharsets.UTF_8));
            if (root.isJsonArray()) {
                for (JsonElement el : root.getAsJsonArray()) {
                    try {
                        AttunementRegistry.register(parseAttunement(el.getAsJsonObject()));
                        loaded++;
                    } catch (Exception e) {
                        ShinobiLogger.error("progression", "Failed to parse attunement", e);
                    }
                }
            }
        } catch (Exception e) {
            ShinobiLogger.error("progression", "Failed to read attunement data", e);
        }
        ShinobiLogger.module("progression", "Loaded " + loaded + " attunement elements");
    }

    private static TreeNodeDefinition parseTreeNode(JsonObject obj) {
        String id = obj.get("id").getAsString();
        String branch = obj.has("branch") ? obj.get("branch").getAsString() : "general";
        int distance = obj.has("distance") ? obj.get("distance").getAsInt() : 0;
        String type = obj.has("type") ? obj.get("type").getAsString() : "passive";
        String jutsuId = obj.has("jutsuId") ? obj.get("jutsuId").getAsString() : null;
        int spCost = obj.has("spCost") ? obj.get("spCost").getAsInt() : 1;
        String icon = obj.has("icon") ? obj.get("icon").getAsString() : "?";
        String name = obj.has("name") ? obj.get("name").getAsString() : id;
        String desc = obj.has("description") ? obj.get("description").getAsString() : "";
        String clanReq = obj.has("clanRequired") ? obj.get("clanRequired").getAsString() : null;

        List<String> requires = new ArrayList<>();
        if (obj.has("requires") && obj.get("requires").isJsonArray()) {
            for (JsonElement req : obj.getAsJsonArray("requires")) {
                requires.add(req.getAsString());
            }
        }

        return new TreeNodeDefinition(id, branch, distance, type, jutsuId,
            spCost, requires, icon, name, desc, clanReq);
    }

    private static AttunementDefinition parseAttunement(JsonObject obj) {
        String id = obj.get("id").getAsString();
        String name = obj.has("name") ? obj.get("name").getAsString() : id;
        boolean combined = obj.has("combined") && obj.get("combined").getAsBoolean();

        List<String> components = new ArrayList<>();
        if (obj.has("components") && obj.get("components").isJsonArray()) {
            for (JsonElement c : obj.getAsJsonArray("components")) {
                components.add(c.getAsString());
            }
        }

        return new AttunementDefinition(id, name, combined, components);
    }
}