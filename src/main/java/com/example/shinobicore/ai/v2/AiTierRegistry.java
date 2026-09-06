package com.example.shinobicore.ai.v2;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class AiTierRegistry {
    private static final Map<String, AiTierDefinition> TIERS = new HashMap<>();

    public static void reload(ResourceManager manager) {
        TIERS.clear();
        Map<Identifier, List<Resource>> resources = manager.findAllResources("ai_tiers", 
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));
        
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            try (InputStream stream = entry.getValue().get(0).getInputStream()) {
                JsonObject json = JsonParser.parseReader(new InputStreamReader(stream)).getAsJsonObject();
                AiTierDefinition def = new AiTierDefinition();
                def.id = json.get("id").getAsString();
                def.displayName = json.get("displayName").getAsString();
                def.healthMultiplier = json.get("healthMultiplier").getAsFloat();
                def.speedMultiplier = json.get("speedMultiplier").getAsFloat();
                def.damageMultiplier = json.get("damageMultiplier").getAsFloat();
                def.canUseEnvironment = json.get("canUseEnvironment").getAsBoolean();
                def.canInterruptCasts = json.get("canInterruptCasts").getAsBoolean();
                
                Map<String, Float> thresholds = new HashMap<>();
                JsonObject thJson = json.getAsJsonObject("thresholds");
                for (String key : thJson.keySet()) {
                    thresholds.put(key, thJson.get(key).getAsFloat());
                }
                def.thresholds = thresholds;
                
                TIERS.put(def.id, def);
                ShinobiCore.LOGGER.info("Loaded AI tier: {}", def.id);
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("Failed to load AI tier", e);
            }
        }
    }

    public static AiTierDefinition get(String id) { return TIERS.get(id); }
}