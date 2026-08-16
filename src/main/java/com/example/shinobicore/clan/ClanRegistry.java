package com.example.shinobicore.clan;

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
import java.util.Random;

public class ClanRegistry {
    private static final Map<String, ClanDefinition> CLANS = new HashMap<>();
    private static final Random RANDOM = new Random();

    public static void reload(ResourceManager manager) {
        CLANS.clear();
        Map<Identifier, List<Resource>> resources = manager.findAllResources("clans",
            resId -> resId.getNamespace().equals(ShinobiCore.MOD_ID) && resId.getPath().endsWith(".json"));
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            Identifier id = entry.getKey();
            for (Resource resource : entry.getValue()) {
                try (InputStream stream = resource.getInputStream()) {
                    JsonObject json = JsonParser.parseReader(
                        new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                    if (!json.has("id")) {
                        String path = id.getPath();
                        String name = path.substring("clans/".length(), path.length() - ".json".length());
                        json.addProperty("id", name);
                    }
                    ClanDefinition def = parse(json);
                    if (def != null) {
                        CLANS.put(def.id(), def);
                        ShinobiCore.LOGGER.info("Loaded clan: {}", def.id());
                    }
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("Failed to load clan from {}: {}", entry.getKey(), e.getMessage());
                }
            }
        }
        ShinobiCore.LOGGER.info("Loaded {} clans", CLANS.size());
    }

    private static ClanDefinition parse(JsonObject json) {
        String id = json.get("id").getAsString();
        String name = json.has("name") ? json.get("name").getAsString() : id;
        ElementType affinity = null;
        if (json.has("affinity") && !json.get("affinity").isJsonNull()) {
            String affId = json.get("affinity").getAsString();
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(affId)) { affinity = e; break; }
            }
        }
        int extraAffinityCount = json.has("extraAffinityCount") ? json.get("extraAffinityCount").getAsInt() : 0;
        Map<String, Integer> statBonuses = new HashMap<>();
        if (json.has("statBonuses")) {
            JsonObject obj = json.getAsJsonObject("statBonuses");
            for (String key : obj.keySet()) statBonuses.put(key, obj.get(key).getAsInt());
        }
        Map<String, Integer> natureBonuses = new HashMap<>();
        if (json.has("natureBonuses")) {
            JsonObject obj = json.getAsJsonObject("natureBonuses");
            for (String key : obj.keySet()) natureBonuses.put(key, obj.get(key).getAsInt());
        }
        Map<String, Float> costMultiplier = new HashMap<>();
        if (json.has("costMultiplier")) {
            JsonObject obj = json.getAsJsonObject("costMultiplier");
            for (String key : obj.keySet()) costMultiplier.put(key, obj.get(key).getAsFloat());
        }
        float fatigueMultiplier = json.has("fatigueMultiplier") ? json.get("fatigueMultiplier").getAsFloat() : 1.0f;
        float reserveBonus = json.has("reserveBonus") ? json.get("reserveBonus").getAsFloat() : 0f;
        String dojutsuHook = json.has("dojutsuHook") && !json.get("dojutsuHook").isJsonNull()
                ? json.get("dojutsuHook").getAsString() : null;
        int chakraCap = json.has("chakraCap") ? json.get("chakraCap").getAsInt() : 2000;

                List<String> startingJutsu = new java.util.ArrayList<>();
        if (json.has("starting_jutsu") && json.get("starting_jutsu").isJsonArray()) {
            com.google.gson.JsonArray arr = json.getAsJsonArray("starting_jutsu");
            for (int i = 0; i < arr.size(); i++) {
                startingJutsu.add(arr.get(i).getAsString());
            }
        }
        return new ClanDefinition(id, name, affinity, extraAffinityCount,
                statBonuses, natureBonuses, costMultiplier, fatigueMultiplier, reserveBonus, dojutsuHook, chakraCap, startingJutsu);
    }

    public static ClanDefinition get(String id) { return CLANS.get(id); }
    public static Collection<ClanDefinition> getAll() { return CLANS.values(); }
    public static ClanDefinition getRandom() {
        if (CLANS.isEmpty()) return null;
        List<ClanDefinition> list = new java.util.ArrayList<>(CLANS.values());
        return list.get(RANDOM.nextInt(list.size()));
    }
}