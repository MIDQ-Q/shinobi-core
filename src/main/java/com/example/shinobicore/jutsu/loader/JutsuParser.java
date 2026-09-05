package com.example.shinobicore.jutsu.loader;

import com.example.shinobicore.jutsu.core.ActivationDefinition;
import com.example.shinobicore.jutsu.core.EffectDefinition;
import com.example.shinobicore.jutsu.core.FormDefinition;
import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.LevelingDefinition;
import com.example.shinobicore.jutsu.core.PropertyDefinition;
import com.example.shinobicore.jutsu.core.RequirementsDefinition;
import com.example.shinobicore.jutsu.core.SoundDefinition;
import com.example.shinobicore.jutsu.core.VisualDefinition;
import com.example.shinobicore.jutsu.enums.ActivationType;
import com.example.shinobicore.jutsu.enums.EffectSubType;
import com.example.shinobicore.jutsu.enums.EffectType;
import com.example.shinobicore.jutsu.enums.ElementType;
import com.example.shinobicore.jutsu.enums.FormType;
import com.example.shinobicore.jutsu.enums.ResourceType;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.JsonPrimitive;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class JutsuParser {

    public static JutsuDefinition parse(InputStream stream) {
        JsonObject root = JsonParser.parseReader(new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
        return parseFromJson(root);
    }

    public static JutsuDefinition parseFromJson(JsonObject root) {
        String id = root.get("id").getAsString();
        String name = root.get("name").getAsString();
        String description = root.has("description") ? root.get("description").getAsString() : "";
        String category = root.has("category") ? root.get("category").getAsString() : "custom";
        String rank = root.has("rank") ? root.get("rank").getAsString() : "D";
        List<String> tags = new ArrayList<>();
        if (root.has("tags")) root.getAsJsonArray("tags").forEach(t -> tags.add(t.getAsString()));

        FormDefinition form = parseForm(root.getAsJsonObject("form"));
        List<EffectDefinition> effects = new ArrayList<>();
        if (root.has("effects")) root.getAsJsonArray("effects").forEach(e -> effects.add(parseEffect(e.getAsJsonObject())));
        List<PropertyDefinition> properties = new ArrayList<>();
        if (root.has("properties")) root.getAsJsonArray("properties").forEach(p -> properties.add(parseProperty(p.getAsJsonObject())));
        ElementType element = root.has("element") ? ElementType.fromId(root.get("element").getAsString()) : ElementType.NONE;
        ActivationDefinition activation = root.has("activation")
                ? parseActivation(root.getAsJsonObject("activation"))
                : new ActivationDefinition(ActivationType.INSTANT, new HashMap<>());

        Map<ResourceType, Integer> cost = new HashMap<>();
        if (root.has("cost")) {
            JsonObject c = root.getAsJsonObject("cost");
            for (ResourceType t : ResourceType.values()) if (c.has(t.getId())) cost.put(t, c.get(t.getId()).getAsInt());
        }

        RequirementsDefinition requirements = root.has("requirements")
                ? parseRequirements(root.getAsJsonObject("requirements"))
                : new RequirementsDefinition(0, 0, new HashMap<>(), new HashMap<>(), null);

        LevelingDefinition leveling = root.has("leveling")
                ? parseLeveling(root.getAsJsonObject("leveling"))
                : new LevelingDefinition(1, new HashMap<>());

        VisualDefinition visual = root.has("visual") ? parseVisual(root.getAsJsonObject("visual"))
                : new VisualDefinition(null, null, null, null, 1.0, false);
        SoundDefinition sound = root.has("sound") ? parseSound(root.getAsJsonObject("sound"))
                : new SoundDefinition(null, null, null, null);
        double cooldown = root.has("cooldown") ? root.get("cooldown").getAsDouble() : 0;

        return new JutsuDefinition(id, name, description, category, rank, tags, form, effects, properties, element,
                activation, cost, requirements, leveling, visual, sound, cooldown);
    }

    private static Map<String, Object> parseParams(JsonObject parent) {
        Map<String, Object> params = new HashMap<>();
        if (parent.has("params")) {
            JsonObject p = parent.getAsJsonObject("params");
            for (String key : p.keySet()) {
                JsonElement val = p.get(key);
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

    private static FormDefinition parseForm(JsonObject o) {
        return new FormDefinition(FormType.fromId(o.get("type").getAsString()), parseParams(o));
    }

    private static EffectDefinition parseEffect(JsonObject o) {
        return new EffectDefinition(
                EffectType.fromId(o.get("type").getAsString()),
                EffectSubType.fromId(o.get("subtype").getAsString()),
                parseParams(o));
    }

    private static PropertyDefinition parseProperty(JsonObject o) {
        return new PropertyDefinition(o.get("id").getAsString(), parseParams(o));
    }

    private static ActivationDefinition parseActivation(JsonObject o) {
        return new ActivationDefinition(ActivationType.fromId(o.get("type").getAsString()), parseParams(o));
    }

    private static RequirementsDefinition parseRequirements(JsonObject o) {
        int uses = o.has("uses") ? o.get("uses").getAsInt() : 0;
        int sp = o.has("sp") ? o.get("sp").getAsInt() : 0;
        Map<String, Integer> stats = new HashMap<>();
        if (o.has("stats")) for (String k : o.getAsJsonObject("stats").keySet()) stats.put(k, o.getAsJsonObject("stats").get(k).getAsInt());
        Map<String, Integer> elements = new HashMap<>();
        if (o.has("elements")) for (String k : o.getAsJsonObject("elements").keySet()) elements.put(k, o.getAsJsonObject("elements").get(k).getAsInt());
        String dojutsu = o.has("dojutsu") ? o.get("dojutsu").getAsString() : null;
        return new RequirementsDefinition(uses, sp, stats, elements, dojutsu);
    }

    private static LevelingDefinition parseLeveling(JsonObject o) {
        int maxLevel = o.has("maxLevel") ? o.get("maxLevel").getAsInt() : 1;
        Map<Integer, LevelingDefinition.LevelData> levels = new HashMap<>();
        if (o.has("levels")) {
            JsonObject lo = o.getAsJsonObject("levels");
            for (String lvStr : lo.keySet()) {
                int lv = Integer.parseInt(lvStr);
                JsonObject row = lo.getAsJsonObject(lvStr);
                Map<String, Double> nums = new HashMap<>();
                Map<String, Integer> reqs = new HashMap<>();
                List<String> unlockProps = new ArrayList<>();
                List<EffectDefinition> unlockFx = new ArrayList<>();
                for (String key : row.keySet()) {
                    JsonElement v = row.get(key);
                    if (v.isJsonPrimitive() && v.getAsJsonPrimitive().isNumber()) {
                        nums.put(key, v.getAsDouble());
                    }
                }
                if (row.has("requirements")) {
                    JsonObject rq = row.getAsJsonObject("requirements");
                    if (rq.has("uses")) reqs.put("uses", rq.get("uses").getAsInt());
                    if (rq.has("sp")) reqs.put("sp", rq.get("sp").getAsInt());
                    if (rq.has("stats")) for (String k : rq.getAsJsonObject("stats").keySet()) reqs.put(k, rq.getAsJsonObject("stats").get(k).getAsInt());
                    if (rq.has("elements")) for (String k : rq.getAsJsonObject("elements").keySet()) reqs.put("el_" + k, rq.getAsJsonObject("elements").get(k).getAsInt());
                }
                if (row.has("unlock")) {
                    JsonObject un = row.getAsJsonObject("unlock");
                    if (un.has("properties")) un.getAsJsonArray("properties").forEach(p -> unlockProps.add(p.getAsString()));
                    if (un.has("effects")) un.getAsJsonArray("effects").forEach(e -> unlockFx.add(parseEffect(e.getAsJsonObject())));
                }
                levels.put(lv, new LevelingDefinition.LevelData(nums, reqs, unlockProps, unlockFx));
            }
        }
        return new LevelingDefinition(maxLevel, levels);
    }

    private static VisualDefinition parseVisual(JsonObject o) {
        return new VisualDefinition(
                o.has("particle") ? o.get("particle").getAsString() : null,
                o.has("trail") ? o.get("trail").getAsString() : null,
                o.has("color") ? o.get("color").getAsString() : null,
                o.has("voxelModel") ? o.get("voxelModel").getAsString() : null,
                o.has("scale") ? o.get("scale").getAsDouble() : 1.0,
                o.has("glow") && o.get("glow").getAsBoolean());
    }

    private static SoundDefinition parseSound(JsonObject o) {
        return new SoundDefinition(
                o.has("cast") ? o.get("cast").getAsString() : null,
                o.has("hit") ? o.get("hit").getAsString() : null,
                o.has("loop") ? o.get("loop").getAsString() : null,
                o.has("end") ? o.get("end").getAsString() : null);
    }
}