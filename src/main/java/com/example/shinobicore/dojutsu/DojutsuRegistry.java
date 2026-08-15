package com.example.shinobicore.dojutsu;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class DojutsuRegistry {
    private static final Map<String, DojutsuDefinition> DOJUTSU = new HashMap<>();

    public static void reload(ResourceManager manager) {
        DOJUTSU.clear();
        Map<Identifier, List<Resource>> resources = manager.findAllResources("dojutsu",
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            for (Resource resource : entry.getValue()) {
                try (InputStream stream = resource.getInputStream()) {
                    JsonObject json = JsonParser.parseReader(
                        new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                    DojutsuDefinition def = parse(json);
                    DOJUTSU.put(def.id(), def);
                    ShinobiCore.LOGGER.info("Loaded dojutsu: {}", def.id());
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("Failed to load dojutsu: {}", e.getMessage());
                }
            }
        }
        ShinobiCore.LOGGER.info("Loaded {} dojutsu", DOJUTSU.size());
    }

    public static DojutsuDefinition get(String id) { return DOJUTSU.get(id); }
    public static Collection<DojutsuDefinition> getAll() { return DOJUTSU.values(); }
    public static boolean exists(String id) { return DOJUTSU.containsKey(id); }

    private static DojutsuDefinition parse(JsonObject json) {
        String id = json.get("id").getAsString();
        String name = json.has("name") ? json.get("name").getAsString() : id;
        String clanId = json.has("clanId") ? json.get("clanId").getAsString() : null;
        List<String> granted = new ArrayList<>();
        if (json.has("grantedJutsu")) {
            JsonArray arr = json.getAsJsonArray("grantedJutsu");
            for (int i = 0; i < arr.size(); i++) granted.add(arr.get(i).getAsString());
        }
        float dmgMult = json.has("damageMultiplier") ? json.get("damageMultiplier").getAsFloat() : 1.0f;
        float costRed = json.has("costReduction") ? json.get("costReduction").getAsFloat() : 0f;
        String desc = json.has("description") ? json.get("description").getAsString() : "";
        return new DojutsuDefinition(id, name, clanId, granted, dmgMult, costRed, desc);
    }
}