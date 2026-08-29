package com.example.shinobicore.dojutsu;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.fabricmc.fabric.api.resource.ResourceManagerHelper;
import net.fabricmc.fabric.api.resource.SimpleSynchronousResourceReloadListener;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.resource.ResourceType;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

/**
 * Loads dojutsu definitions from data/shinobicore/dojutsu/*.json.
 * HLD: Section 7. Fail-Safe: bad JSON is logged and skipped.
 */
public final class DojutsuRegistry {

    private static final Map<String, DojutsuDefinition> DOJUTSU = new HashMap<>();

    private DojutsuRegistry() {}

    public static void registerReloadListener() {
        ResourceManagerHelper.get(ResourceType.SERVER_DATA).registerReloadListener(
            new SimpleSynchronousResourceReloadListener() {
                @Override
                public Identifier getFabricId() {
                    return new Identifier(ShinobiCore.MOD_ID, "dojutsu_registry");
                }
                @Override
                public void reload(ResourceManager manager) {
                    DojutsuRegistry.reload(manager);
                }
            }
        );
    }

    public static void reload(ResourceManager manager) {
        DOJUTSU.clear();
        Map<Identifier, Resource> resources = manager.findResources(
            "dojutsu", id -> id.getPath().endsWith(".json"));
        for (Map.Entry<Identifier, Resource> entry : resources.entrySet()) {
            if (!ShinobiCore.MOD_ID.equals(entry.getKey().getNamespace())) continue;
            try (InputStream stream = entry.getValue().getInputStream()) {
                JsonObject json = JsonParser.parseReader(
                    new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                DojutsuDefinition def = parse(json);
                if (def != null) {
                    DOJUTSU.put(def.id(), def);
                    ShinobiCore.LOGGER.info("Loaded dojutsu: {}", def.id());
                }
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("Failed to load dojutsu {}: {}", entry.getKey(), e.getMessage());
            }
        }
        ShinobiCore.LOGGER.info("DojutsuRegistry loaded {} dojutsu", DOJUTSU.size());
    }

    private static DojutsuDefinition parse(JsonObject json) {
        if (!json.has("id") || !json.has("dojutsuType")) {
            ShinobiCore.LOGGER.warn("[WARN] Dojutsu JSON missing id/dojutsuType, skipped");
            return null;
        }
        return new DojutsuDefinition(
            json.get("id").getAsString(),
            json.has("name") ? json.get("name").getAsString() : json.get("id").getAsString(),
            json.get("dojutsuType").getAsString(),
            json.has("clan") ? json.get("clan").getAsString() : "",
            json.has("maxStress") ? json.get("maxStress").getAsInt() : 100,
            json.has("usagePerStage") ? json.get("usagePerStage").getAsInt() : 50
        );
    }

    public static DojutsuDefinition get(String id) { return DOJUTSU.get(id); }
}