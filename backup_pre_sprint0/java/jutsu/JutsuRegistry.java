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
import java.util.*;

public class JutsuRegistry {
    private static final Map<String, JutsuDefinition> JUTSUS = new LinkedHashMap<>();
    private static int invalidCount = 0;

    public static void reload(ResourceManager manager) {
        JUTSUS.clear();
        invalidCount = 0;
        Map<Identifier, List<Resource>> resources = manager.findAllResources("jutsu",
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));
        
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            for (Resource resource : entry.getValue()) {
                try (InputStream stream = resource.getInputStream()) {
                    // Skip template files
                    if (entry.getKey().getPath().contains("_template")) continue;

                    JsonObject json = JsonParser.parseReader(
                        new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                    
                    JutsuDefinition def = parse(json);
                    if (def == null) {
                        invalidCount++;
                        continue;
                    }
                    
                    if (JUTSUS.containsKey(def.id())) {
                        ShinobiCore.LOGGER.warn("[JutsuRegistry] Duplicate ID: {}", def.id());
                        invalidCount++;
                        continue;
                    }

                    JUTSUS.put(def.id(), def);
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("[JutsuRegistry] Failed to load jutsu from {}: {}", entry.getKey(), e.getMessage());
                    invalidCount++;
                }
            }
        }
        ShinobiCore.LOGGER.info("[JutsuRegistry] Loaded {} jutsu ({} invalid/skipped)", JUTSUS.size(), invalidCount);
    }

    public static JutsuDefinition get(String id) { return JUTSUS.get(id); }
    public static Collection<JutsuDefinition> getAll() { return JUTSUS.values(); }

    private static JutsuDefinition parse(JsonObject json) {
        if (!json.has("id") || !json.has("name")) {
            ShinobiCore.LOGGER.error("[JutsuRegistry] Missing id or name in JSON");
            return null;
        }

        String id = json.get("id").getAsString();
        String name = json.get("name").getAsString();
        
        // S0-03 Fields (with fallback to legacy names for backwards compatibility)
        // S1-04: Auto-detect tier from cost if not specified
        int tier;
        if (json.has("tier")) {
            tier = json.get("tier").getAsInt();
        } else {
            float autoCost = json.has("chakra_cost") ? json.get("chakra_cost").getAsFloat() :
                             (json.has("baseCost") ? json.get("baseCost").getAsFloat() : 0f);
            if (autoCost <= 15) tier = 1;
            else if (autoCost <= 25) tier = 2;
            else if (autoCost <= 40) tier = 3;
            else if (autoCost <= 60) tier = 4;
            else tier = 5;
        }
        
        ElementType element = null;
        String elemStr = json.has("element") ? json.get("element").getAsString() : 
                         (json.has("nature") ? json.get("nature").getAsString() : null);
        if (elemStr != null) {
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(elemStr)) { element = e; break; }
            }
        }
        
        float chakraCost = json.has("chakra_cost") ? json.get("chakra_cost").getAsFloat() : 
                           (json.has("baseCost") ? json.get("baseCost").getAsFloat() : 0f);
        float staminaCost = json.has("stamina_cost") ? json.get("stamina_cost").getAsFloat() : 0f;
        float castTime = json.has("cast_time") ? json.get("cast_time").getAsFloat() : 0f; // S1-03: 0 = use tier default
        boolean chargeable = json.has("chargeable") && json.get("chargeable").getAsBoolean();
        float chargeMax = json.has("charge_max") ? json.get("charge_max").getAsFloat() : 1.0f;
        
        Map<String, Integer> requires = new HashMap<>();
        JsonObject reqObj = json.has("requires") ? json.getAsJsonObject("requires") : 
                            (json.has("requirements") ? json.getAsJsonObject("requirements") : null);
        if (reqObj != null) {
            for (String key : reqObj.keySet()) {
                requires.put(key, reqObj.get(key).getAsInt());
            }
        }
        
        List<String> tags = new ArrayList<>();
        if (json.has("tags") && json.get("tags").isJsonArray()) {
            for (var t : json.getAsJsonArray("tags")) tags.add(t.getAsString());
        }
        
        String visual = json.has("visual") ? json.get("visual").getAsString() : null;
        String sfx = json.has("sfx") ? json.get("sfx").getAsString() : null;
        boolean requiresTeacher = json.has("requires_teacher") && json.get("requires_teacher").getAsBoolean();
        String requiresScroll = json.has("requires_scroll") && !json.get("requires_scroll").isJsonNull() 
                                ? json.get("requires_scroll").getAsString() : null;

        // Legacy fields
        String category = json.has("category") ? json.get("category").getAsString() : "unknown";
        String type = json.has("type") ? json.get("type").getAsString() : "projectile";
        String behaviorClass = json.has("behaviorClass") && !json.get("behaviorClass").isJsonNull() 
                               ? json.get("behaviorClass").getAsString() : null;
        JsonObject params = json.has("params") ? json.getAsJsonObject("params") : new JsonObject();
        float baseDamage = json.has("baseDamage") ? json.get("baseDamage").getAsFloat() : 0f;
        float strain = json.has("strain") ? json.get("strain").getAsFloat() : 0f;
        int reqUses = json.has("requiredUsesForFullProficiency") ? json.get("requiredUsesForFullProficiency").getAsInt() : 50;
        String reqDojutsu = json.has("requiresDojutsu") && !json.get("requiresDojutsu").isJsonNull() 
                             ? json.get("requiresDojutsu").getAsString() : null;

        // === VALIDATION ===
        if (chakraCost < 0 || staminaCost < 0 || baseDamage < 0 || strain < 0) {
            ShinobiCore.LOGGER.error("[JutsuRegistry] Negative cost/damage/strain in {}", id);
            return null;
        }
        if (tier < 1 || tier > 5) {
            ShinobiCore.LOGGER.warn("[JutsuRegistry] Tier {} out of bounds (1-5) for {}", tier, id);
            tier = Math.max(1, Math.min(5, tier));
        }

        return new JutsuDefinition(
            id, name, tier, element, chakraCost, staminaCost, castTime, chargeable, chargeMax,
            requires, tags, visual, sfx, requiresTeacher, requiresScroll,
            category, type, behaviorClass, params, baseDamage, strain, reqUses, reqDojutsu
        );
    }
}