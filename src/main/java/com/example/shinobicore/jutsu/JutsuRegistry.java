package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;
import java.util.List;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;

public class JutsuRegistry {
    private static final Map<String, JutsuDefinition> JUTSU = new HashMap<>();

 public static void reload(ResourceManager manager) {
    JUTSU.clear();

    // В 1.20.1 findAllResources возвращает Map<Identifier, List<Resource>>
    Map<Identifier, List<Resource>> resources = manager.findAllResources("jutsu", 
        id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json")
    );

    for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
        Identifier id = entry.getKey();
        List<Resource> resourceList = entry.getValue();
        
        // Берём первый ресурс из списка (самый приоритетный)
        if (resourceList.isEmpty()) continue;
        Resource resource = resourceList.get(0);
        
        try (InputStream stream = resource.getInputStream()) {
            JsonObject json = JsonParser.parseReader(new InputStreamReader(stream)).getAsJsonObject();
            
            // Если в JSON нет поля id, генерируем его из пути файла
            if (!json.has("id")) {
                String path = id.getPath(); // например "jutsu/fireball.json"
                String name = path.substring("jutsu/".length(), path.length() - ".json".length());
                json.addProperty("id", ShinobiCore.MOD_ID + ":" + name);
            }

            JutsuDefinition def = parse(json);
            if (def != null) {
                JUTSU.put(def.id(), def);
                ShinobiCore.LOGGER.info("Loaded jutsu: {}", def.id());
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to load jutsu from {}: {}", id, e.getMessage());
        }
    }

    ShinobiCore.LOGGER.info("Loaded {} jutsu", JUTSU.size());
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

        return new JutsuDefinition(
            id, name, category, nature, type, params,
            baseCost, baseDamage, strain,
            requiredUses, requirements
        );
    }

    public static JutsuDefinition get(String id) {
        return JUTSU.get(id);
    }

    public static Collection<JutsuDefinition> getAll() {
        return JUTSU.values();
    }
}