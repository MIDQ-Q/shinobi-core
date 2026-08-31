package com.example.shinobicore.modules.jutsu.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.fabricmc.loader.api.FabricLoader;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

public final class JutsuLoader {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    public static void load() {
        JutsuRegistry.clear();
        Path jutsuDir = FabricLoader.getInstance().getModContainer("shinobicore")
                .flatMap(c -> c.findPath("data/shinobicore/jutsu"))
                .orElseThrow(() -> new RuntimeException("Cannot find jutsu data path"));

        if (!Files.isDirectory(jutsuDir)) {
            ShinobiLogger.module("jutsu", "Jutsu data directory not found. Skipping load.");
            return;
        }

        final int[] loadedCount = {0};
        final int[] errorCount = {0};

        try (var stream = Files.walk(jutsuDir)) {
            stream.filter(Files::isRegularFile)
                  .filter(p -> p.toString().endsWith(".json"))
                  .forEach(path -> {
                      try {
                          String json = Files.readString(path);
                          JsonObject obj = JsonParser.parseString(json).getAsJsonObject();
                          JutsuDefinition def = parseDefinition(obj);
                          if (def != null) {
                              JutsuRegistry.register(def);
                              loadedCount[0]++;
                          }
                      } catch (Exception e) {
                          errorCount[0]++;
                          ShinobiLogger.error("jutsu", "Failed to load jutsu from: " + path.getFileName(), e);
                      }
                  });
        } catch (IOException e) {
            ShinobiLogger.error("jutsu", "Failed to read jutsu directory", e);
        }

        ShinobiLogger.module("jutsu", String.format("Loaded %d jutsu definitions. Errors: %d", loadedCount[0], errorCount[0]));
    }

    private static JutsuDefinition parseDefinition(JsonObject obj) {
        try {
            String id = obj.has("id") ? obj.get("id").getAsString() : "unknown";
            String name = obj.has("name") ? obj.get("name").getAsString() : "Unnamed";
            String elementStr = obj.has("element") ? obj.get("element").getAsString() : "none";
            JutsuElement element = JutsuElement.fromString(elementStr);
            String behaviorId = obj.has("behavior") ? obj.get("behavior").getAsString() : "utility";
            
            float baseCost = obj.has("baseCost") ? obj.get("baseCost").getAsFloat() : 0.0f;
            int cooldownTicks = obj.has("cooldownTicks") ? obj.get("cooldownTicks").getAsInt() : 0;
            int prepareTicks = obj.has("prepareTicks") ? obj.get("prepareTicks").getAsInt() : 0;
            int chargeTicks = obj.has("chargeTicks") ? obj.get("chargeTicks").getAsInt() : 0;
            int releaseTicks = obj.has("releaseTicks") ? obj.get("releaseTicks").getAsInt() : 1;
            float maxChargeMultiplier = obj.has("maxChargeMultiplier") ? obj.get("maxChargeMultiplier").getAsFloat() : 1.0f;

            JutsuDefinition.Requirements req = parseRequirements(obj.getAsJsonObject("requirements"));
            JsonObject behaviorData = obj.has("behaviorData") ? obj.getAsJsonObject("behaviorData") : new JsonObject();
            JutsuDefinition.Scaling scaling = parseScaling(obj.getAsJsonObject("scaling"));
            JutsuDefinition.VisualData visual = parseVisual(obj.getAsJsonObject("visual"));

            return new JutsuDefinition(id, name, element, behaviorId, baseCost, cooldownTicks, 
                    prepareTicks, chargeTicks, releaseTicks, maxChargeMultiplier, req, behaviorData, scaling, visual);
        } catch (Exception e) {
            ShinobiLogger.error("jutsu", "Malformed jutsu definition skipped", e);
            return null;
        }
    }

    private static JutsuDefinition.Requirements parseRequirements(JsonObject obj) {
        if (obj == null) return new JutsuDefinition.Requirements(1, List.of(), Map.of(), false, null, null, null);
        int minLvl = obj.has("minPlayerLevel") ? obj.get("minPlayerLevel").getAsInt() : 1;
        boolean clan = obj.has("clanJutsu") && obj.get("clanJutsu").getAsBoolean();
        return new JutsuDefinition.Requirements(minLvl, List.of(), Map.of(), clan, null, null, null);
    }

    private static JutsuDefinition.Scaling parseScaling(JsonObject obj) {
        if (obj == null) return new JutsuDefinition.Scaling(0.0f, 0.0f, 0);
        float dmg = obj.has("damagePerLevel") ? obj.get("damagePerLevel").getAsFloat() : 0.0f;
        float cost = obj.has("costReductionPerLevel") ? obj.get("costReductionPerLevel").getAsFloat() : 0.0f;
        int cd = obj.has("cooldownReductionPerLevel") ? obj.get("cooldownReductionPerLevel").getAsInt() : 0;
        return new JutsuDefinition.Scaling(dmg, cost, cd);
    }

    private static JutsuDefinition.VisualData parseVisual(JsonObject obj) {
        if (obj == null) return new JutsuDefinition.VisualData(List.of(), "#FFFFFF", "", "");
        return new JutsuDefinition.VisualData(List.of(), "#FFFFFF", "", "");
    }
}