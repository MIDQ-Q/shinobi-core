package com.example.shinobicore.jutsu.data;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonElement;
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
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;

/**
 * Loads jutsu definitions from data/shinobicore/jutsu/*.json
 * HLD: Section 2.2, 2.11 (Fail-Safe validation, no crash on bad JSON)
 */
public final class JutsuRegistry {

    private static final Map<String, JutsuDefinition> JUTSUS = new HashMap<>();

    private JutsuRegistry() {}

    /**
     * Register reload listener so JSONs load on server start and /reload.
     */
    public static void registerReloadListener() {
        ResourceManagerHelper.get(ResourceType.SERVER_DATA).registerReloadListener(
            new SimpleSynchronousResourceReloadListener() {
                @Override
                public Identifier getFabricId() {
                    return new Identifier(ShinobiCore.MOD_ID, "jutsu_registry");
                }

                @Override
                public void reload(ResourceManager manager) {
                    JutsuRegistry.reload(manager);
                }
            }
        );
        ShinobiCore.LOGGER.info("JutsuRegistry reload listener registered");
    }

    public static void reload(ResourceManager manager) {
        JUTSUS.clear();
        Map<Identifier, Resource> resources = manager.findResources(
            "jutsu", id -> id.getPath().endsWith(".json")
        );

        for (Map.Entry<Identifier, Resource> entry : resources.entrySet()) {
            Identifier resId = entry.getKey();
            if (!ShinobiCore.MOD_ID.equals(resId.getNamespace())) {
                continue;
            }
            try (InputStream stream = entry.getValue().getInputStream()) {
                JsonObject json = JsonParser.parseReader(
                    new InputStreamReader(stream, StandardCharsets.UTF_8)
                ).getAsJsonObject();

                JutsuDefinition def = parse(json);
                if (def != null) {
                    JUTSUS.put(def.id(), def);
                    ShinobiCore.LOGGER.info("Loaded jutsu: {}", def.id());
                }
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("Failed to load jutsu from {}: {}", resId, e.getMessage());
            }
        }
        ShinobiCore.LOGGER.info("JutsuRegistry loaded {} jutsus", JUTSUS.size());
    }

    /**
     * Parse JSON into JutsuDefinition. Returns null on invalid data (Fail-Safe).
     */
    private static JutsuDefinition parse(JsonObject json) {
        if (!json.has("id") || !json.has("behavior")) {
            ShinobiCore.LOGGER.warn("[WARN] Jutsu JSON missing 'id' or 'behavior', skipped");
            return null;
        }

        String id = json.get("id").getAsString();
        String behavior = json.get("behavior").getAsString();

        String name = getString(json, "name", id);
        String category = getString(json, "category", "elemental");
        String element = getString(json, "element", "");
        String rank = getString(json, "rank", "D");

        String behaviorClass = null;
        if (json.has("behaviorClass") && !json.get("behaviorClass").isJsonNull()) {
            behaviorClass = json.get("behaviorClass").getAsString();
        }

        JsonObject params = new JsonObject();
        if (json.has("params") && json.get("params").isJsonObject()) {
            params = json.getAsJsonObject("params");
        }

        JsonObject visuals = new JsonObject();
        if (json.has("visuals") && json.get("visuals").isJsonObject()) {
            visuals = json.getAsJsonObject("visuals");
        }

        Map<String, Integer> requirements = new HashMap<>();
        if (json.has("requirements") && json.get("requirements").isJsonObject()) {
            JsonObject req = json.getAsJsonObject("requirements");
            for (Map.Entry<String, JsonElement> e : req.entrySet()) {
                try {
                    requirements.put(e.getKey(), e.getValue().getAsInt());
                } catch (Exception ex) {
                    ShinobiCore.LOGGER.warn("[WARN] Jutsu '{}' has invalid requirement '{}'", id, e.getKey());
                }
            }
        }

        float baseCost = getFloat(json, "baseCost", 0.0f);
        float baseDamage = getFloat(json, "baseDamage", 0.0f);
        float strain = getFloat(json, "strain", 0.0f);
        boolean chargeable = json.has("chargeable") && json.get("chargeable").getAsBoolean();

        String requiresDojutsu = null;
        if (json.has("requiresDojutsu") && !json.get("requiresDojutsu").isJsonNull()) {
            requiresDojutsu = json.get("requiresDojutsu").getAsString();
        }
        String requiresScroll = null;
        if (json.has("requiresScroll") && !json.get("requiresScroll").isJsonNull()) {
            requiresScroll = json.get("requiresScroll").getAsString();
        }

        return new JutsuDefinition(
            id, name, category, element, rank, behavior, behaviorClass,
            params, visuals, requirements, baseCost, baseDamage, strain,
            chargeable, requiresDojutsu, requiresScroll
        );
    }

    private static String getString(JsonObject json, String key, String def) {
        if (json.has(key) && !json.get(key).isJsonNull()) {
            return json.get(key).getAsString();
        }
        return def;
    }

    private static float getFloat(JsonObject json, String key, float def) {
        if (json.has(key) && !json.get(key).isJsonNull()) {
            return json.get(key).getAsFloat();
        }
        return def;
    }

    public static JutsuDefinition get(String id) {
        return JUTSUS.get(id);
    }

    public static Collection<JutsuDefinition> getAll() {
        return JUTSUS.values();
    }

    public static int size() {
        return JUTSUS.size();
    }
}