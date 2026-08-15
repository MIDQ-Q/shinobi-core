package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class JutsuRegistry {

    private static final Map<String, JutsuDefinition> JUTSUS = new HashMap<>();

    public static void reload(ResourceManager manager) {
        JUTSUS.clear();

        Map<Identifier, List<Resource>> resources = manager.findAllResources("jutsu",
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));

        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            for (Resource resource : entry.getValue()) {
                try (InputStream stream = resource.getInputStream()) {
                    JsonObject json = JsonParser.parseReader(
                        new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                    JutsuDefinition def = parse(json);
                    JUTSUS.put(def.id(), def);
                    ShinobiCore.LOGGER.info("Loaded jutsu: {}", def.id());
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("Failed to load jutsu from {}: {}", entry.getKey(), e.getMessage());
                }
            }
        }

        ShinobiCore.LOGGER.info("Loaded {} jutsu", JUTSUS.size());
    }

    public static JutsuDefinition get(String id) {
        return JUTSUS.get(id);
    }

    public static Collection<JutsuDefinition> getAll() {
        return JUTSUS.values();
    }

    private static JutsuDefinition parse(JsonObject json) {
        String id = json.get("id").getAsString();
        String name = json.has("name") ? json.get("name").getAsString() : id;
        String category = json.has("category") ? json.get("category").getAsString() : "unknown";

        ElementType nature = null;
        if (json.has("nature") && !json.get("nature").isJsonNull()) {
            String natureId = json.get("nature").getAsString();
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(natureId)) {
                    nature = e;
                    break;
                }
            }
        }

        String type = json.has("type") ? json.get("type").getAsString() : "projectile";

        String behaviorClass = json.has("behaviorClass") && !json.get("behaviorClass").isJsonNull()
            ? json.get("behaviorClass").getAsString() : null;

        JsonObject params = json.has("params") ? json.getAsJsonObject("params") : new JsonObject();

        float baseCost = json.has("baseCost") ? json.get("baseCost").getAsFloat() : 0f;
        float baseDamage = json.has("baseDamage") ? json.get("baseDamage").getAsFloat() : 0f;
        float strain = json.has("strain") ? json.get("strain").getAsFloat() : 0f;
        int requiredUses = json.has("requiredUsesForFullProficiency")
            ? json.get("requiredUsesForFullProficiency").getAsInt()
            : 50;

        Map<String, Integer> requirements = new HashMap<>();
        if (json.has("requirements")) {
            JsonObject reqObj = json.getAsJsonObject("requirements");
            for (String key : reqObj.keySet()) {
                requirements.put(key, reqObj.get(key).getAsInt());
            }
        }

        String requiresDojutsu = json.has("requiresDojutsu") && !json.get("requiresDojutsu").isJsonNull()
            ? json.get("requiresDojutsu").getAsString() : null;
        String requiresScroll = json.has("requiresScroll") && !json.get("requiresScroll").isJsonNull()
            ? json.get("requiresScroll").getAsString() : null;
        return new JutsuDefinition(
            id, name, category, nature, type, behaviorClass, params,
            baseCost, baseDamage, strain,
            requiredUses, requirements, requiresDojutsu, requiresScroll
        );
    }
}