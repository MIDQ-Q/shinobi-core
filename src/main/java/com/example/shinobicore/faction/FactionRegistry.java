package com.example.shinobicore.faction;
import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
public class FactionRegistry {
    private static final Map<String, FactionDefinition> FACTIONS = new HashMap<>();
    public static void reload(ResourceManager manager) {
        FACTIONS.clear();
        Map<Identifier, List<Resource>> resources = manager.findAllResources("factions", id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            Resource resource = entry.getValue().get(0);
            try (InputStream stream = resource.getInputStream()) {
                JsonObject json = JsonParser.parseReader(new InputStreamReader(stream)).getAsJsonObject();
                String id = json.get("id").getAsString();
                String name = json.get("name").getAsString();
                int color = json.get("color").getAsInt();
                int hostile = json.get("hostileThreshold").getAsInt();
                int friendly = json.get("friendlyThreshold").getAsInt();
                FACTIONS.put(id, new FactionDefinition(id, name, color, hostile, friendly));
            } catch (Exception e) { ShinobiCore.LOGGER.error("Failed to load faction", e); }
        }
    }
    public static FactionDefinition get(String id) { return FACTIONS.get(id); }
    public static Collection<FactionDefinition> getAll() { return FACTIONS.values(); }
}