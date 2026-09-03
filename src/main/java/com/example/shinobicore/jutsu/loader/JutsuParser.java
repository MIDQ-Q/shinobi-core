package com.example.shinobicore.jutsu.loader;

import com.example.shinobicore.jutsu.core.*;
import com.example.shinobicore.jutsu.enums.*;
import com.google.gson.*;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * Парсер техник из JSON (новый формат).
 */
public class JutsuParser {

    public static JutsuDefinition parse(InputStream stream) {
        JsonObject root = JsonParser.parseReader(new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
        return parseFromJson(root);
    }

    public static JutsuDefinition parseFromJson(JsonObject root) {
        // Metadata
        String id = root.get("id").getAsString();
        String name = root.get("name").getAsString();
        String description = root.has("description") ? root.get("description").getAsString() : "";
        String category = root.has("category") ? root.get("category").getAsString() : "custom";
        String rank = root.has("rank") ? root.get("rank").getAsString() : "D";
        List<String> tags = new ArrayList<>();
        if (root.has("tags")) {
            root.getAsJsonArray("tags").forEach(t -> tags.add(t.getAsString()));
        }

        // Form
        FormDefinition form = parseForm(root.getAsJsonObject("form"));

        // Effects
        List<EffectDefinition> effects = new ArrayList<>();
        if (root.has("effects")) {
            root.getAsJsonArray("effects").forEach(e -> effects.add(parseEffect(e.getAsJsonObject())));
        }

        // Properties
        List<PropertyDefinition> properties = new ArrayList<>();
        if (root.has("properties")) {
            root.getAsJsonArray("properties").forEach(p -> properties.add(parseProperty(p.getAsJsonObject())));
        }

        // Element
        ElementType element = ElementType.NONE;
        if (root.has("element")) {
            element = ElementType.fromId(root.get("element").getAsString());
        }

        // Activation
        ActivationDefinition activation = root.has("activation")
            ? parseActivation(root.getAsJsonObject("activation"))
            : new ActivationDefinition(ActivationType.INSTANT, new HashMap<>());

        // Cost
        Map<ResourceType, Integer> cost = new HashMap<>();
        if (root.has("cost")) {
            JsonObject costObj = root.getAsJsonObject("cost");
            for (ResourceType type : ResourceType.values()) {
                if (costObj.has(type.getId())) {
                    cost.put(type, costObj.get(type.getId()).getAsInt());
                }
            }
        }

        // Requirements
        RequirementsDefinition requirements = root.has("requirements")
            ? parseRequirements(root.getAsJsonObject("requirements"))
            : new RequirementsDefinition(0, 0, new HashMap<>(), new HashMap<>(), null);

        // Leveling
        LevelingDefinition leveling = root.has("leveling")
            ? parseLeveling(root.getAsJsonObject("leveling"))
            : new LevelingDefinition(1, new HashMap<>());

        // Visual
        VisualDefinition visual = root.has("visual")
            ? parseVisual(root.getAsJsonObject("visual"))
            : new VisualDefinition(null, null, null, null, 1.0, false);

        // Sound
        SoundDefinition sound = root.has("sound")
            ? parseSound(root.getAsJsonObject("sound"))
            : new SoundDefinition(null, null, null, null);

        return new JutsuDefinition(
            id, name, description, category, rank, tags,
            form, effects, properties, element,
            activation, cost, requirements,
            leveling, visual, sound
        );
    }

    private static FormDefinition parseForm(JsonObject formObj) {
        FormType type = FormType.fromId(formObj.get("type").getAsString());
        Map<String, Object> params = parseParams(formObj);
        return new FormDefinition(type, params);
    }

    private static EffectDefinition parseEffect(JsonObject effectObj) {
        EffectType type = EffectType.fromId(effectObj.get("type").getAsString());
        EffectSubType subType = EffectSubType.fromId(effectObj.get("subtype").getAsString());
        Map<String, Object> params = parseParams(effectObj);
        return new EffectDefinition(type, subType, params);
    }

    private static PropertyDefinition parseProperty(JsonObject propObj) {
        String id = propObj.get("id").getAsString();
        Map<String, Object> params = parseParams(propObj);
        return new PropertyDefinition(id, params);
    }

    private static ActivationDefinition parseActivation(JsonObject actObj) {
        ActivationType type = ActivationType.fromId(actObj.get("type").getAsString());
        Map<String, Object> params = parseParams(actObj);
        return new ActivationDefinition(type, params);
    }

    private static RequirementsDefinition parseRequirements(JsonObject reqObj) {
        int uses = reqObj.has("uses") ? reqObj.get("uses").getAsInt() : 0;
        int sp = reqObj.has("sp") ? reqObj.get("sp").getAsInt() : 0;
        Map<String, Integer> stats = new HashMap<>();
        if (reqObj.has("stats")) {
            JsonObject statsObj = reqObj.getAsJsonObject("stats");
            for (String key : statsObj.keySet()) {
                stats.put(key, statsObj.get(key).getAsInt());
            }
        }
        Map<String, Integer> elements = new HashMap<>();
        if (reqObj.has("elements")) {
            JsonObject elementsObj = reqObj.getAsJsonObject("elements");
            for (String key : elementsObj.keySet()) {
                elements.put(key, elementsObj.get(key).getAsInt());
            }
        }
        String dojutsu = reqObj.has("dojutsu") ? reqObj.get("dojutsu").getAsString() : null;
        return new RequirementsDefinition(uses, sp, stats, elements, dojutsu);
    }

    private static LevelingDefinition parseLeveling(JsonObject lvlObj) {
        int maxLevel = lvlObj.has("maxLevel") ? lvlObj.get("maxLevel").getAsInt() : 1;
        Map<Integer, LevelingDefinition.LevelData> levels = new HashMap<>();
        if (lvlObj.has("levels")) {
            JsonObject levelsObj = lvlObj.getAsJsonObject("levels");
            for (String levelStr : levelsObj.keySet()) {
                int level = Integer.parseInt(levelStr);
                JsonObject levelData = levelsObj.getAsJsonObject(levelStr);
                Map<String, Double> numericParams = new HashMap<>();
                Map<String, Integer> requirements = new HashMap<>();
                for (String key : levelData.keySet()) {
                    JsonElement val = levelData.get(key);
                    if (val.isJsonPrimitive() && val.getAsJsonPrimitive().isNumber()) {
                        numericParams.put(key, val.getAsDouble());
                    }
                }
                levels.put(level, new LevelingDefinition.LevelData(numericParams, requirements));
            }
        }
        return new LevelingDefinition(maxLevel, levels);
    }

    private static VisualDefinition parseVisual(JsonObject visObj) {
        String particle = visObj.has("particle") ? visObj.get("particle").getAsString() : null;
        String trailParticle = visObj.has("trail") ? visObj.get("trail").getAsString() : null;
        String color = visObj.has("color") ? visObj.get("color").getAsString() : null;
        String voxelModel = visObj.has("voxelModel") ? visObj.get("voxelModel").getAsString() : null;
        double scale = visObj.has("scale") ? visObj.get("scale").getAsDouble() : 1.0;
        boolean glow = visObj.has("glow") && visObj.get("glow").getAsBoolean();
        return new VisualDefinition(particle, trailParticle, color, voxelModel, scale, glow);
    }

    private static SoundDefinition parseSound(JsonObject sndObj) {
        String cast = sndObj.has("cast") ? sndObj.get("cast").getAsString() : null;
        String hit = sndObj.has("hit") ? sndObj.get("hit").getAsString() : null;
        String loop = sndObj.has("loop") ? sndObj.get("loop").getAsString() : null;
        String end = sndObj.has("end") ? sndObj.get("end").getAsString() : null;
        return new SoundDefinition(cast, hit, loop, end);
    }

    private static Map<String, Object> parseParams(JsonObject parent) {
        Map<String, Object> params = new HashMap<>();
        if (parent.has("params")) {
            JsonObject paramsObj = parent.getAsJsonObject("params");
            for (String key : paramsObj.keySet()) {
                JsonElement val = paramsObj.get(key);
                if (val.isJsonPrimitive()) {
                    JsonPrimitive prim = val.getAsJsonPrimitive();
                    if (prim.isNumber()) params.put(key, prim.getAsDouble());
                    else if (prim.isBoolean()) params.put(key, prim.getAsBoolean());
                    else params.put(key, prim.getAsString());
                }
            }
        }
        return params;
    }
}