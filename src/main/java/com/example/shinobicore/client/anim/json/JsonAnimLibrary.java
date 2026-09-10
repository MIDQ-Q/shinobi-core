package com.example.shinobicore.client.anim.json;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.*;
import net.minecraft.client.model.ModelPart;
import net.minecraft.util.math.MathHelper;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class JsonAnimLibrary {
    private static final Map<String, JsonAnim> ANIMS = new HashMap<>();

    public static class JsonAnim {
        public String name;
        public float length;
        public boolean loop;
        public Map<String, BoneAnim> bones = new HashMap<>();
    }

    public static class BoneAnim {
        public List<Keyframe> rotation = new ArrayList<>();
        public List<Keyframe> position = new ArrayList<>(); // Добавлено для поддержки смещения
    }

    public static class Keyframe {
        public float time;
        public float x, y, z;
    }

    public static void loadAll() {
        ANIMS.clear();
        String[] files = {"shinobi_player_animations.json"};
        for (String f : files) {
            try (InputStream is = JsonAnimLibrary.class.getResourceAsStream("/assets/shinobicore/animations/" + f)) {
                if (is != null) {
                    parseFile(is);
                    ShinobiCore.LOGGER.info("[ShinobiAnim] Loaded: " + f + " (" + ANIMS.size() + " animations)");
                } else {
                    ShinobiCore.LOGGER.info("[ShinobiAnim] NOT FOUND: " + f);
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    private static void parseFile(InputStream is) {
        JsonObject root = JsonParser.parseReader(new InputStreamReader(is, StandardCharsets.UTF_8)).getAsJsonObject();
        JsonObject anims = root.getAsJsonObject("animations");
        if (anims == null) return;

        for (Map.Entry<String, JsonElement> entry : anims.entrySet()) {
            String animName = entry.getKey().trim().replace("animation.shinobi_player.", "");
            JsonObject animObj = entry.getValue().getAsJsonObject();
            JsonAnim anim = new JsonAnim();
            anim.name = animName;
            anim.length = animObj.has("animation_length") ? animObj.get("animation_length").getAsFloat() : 1.0f;
            anim.loop = animObj.has("loop") && animObj.get("loop").getAsBoolean();
            JsonObject bones = animObj.getAsJsonObject("bones");

            if (bones != null) {
                for (Map.Entry<String, JsonElement> boneEntry : bones.entrySet()) {
                    String boneName = normalizeBoneName(boneEntry.getKey().trim());
                    JsonElement boneEl = boneEntry.getValue();
                    BoneAnim boneAnim = new BoneAnim();

                    if (boneEl.isJsonArray()) {
                        for (JsonElement kfEl : boneEl.getAsJsonArray()) {
                            JsonObject kf = kfEl.getAsJsonObject();
                            Keyframe k = new Keyframe();
                            k.time = kf.get("time").getAsFloat();
                            JsonArray val = kf.getAsJsonArray("value");
                            k.x = val.get(0).getAsFloat();
                            k.y = val.get(1).getAsFloat();
                            k.z = val.get(2).getAsFloat();
                            boneAnim.rotation.add(k);
                        }
                    } else if (boneEl.isJsonObject()) {
                        JsonObject boneObj = boneEl.getAsJsonObject();

                        // === НОВОЕ: Парсинг позиции (position) ===
                        if (boneObj.has("position")) {
                            JsonElement posEl = boneObj.get("position");
                            if (posEl.isJsonObject()) {
                                for (Map.Entry<String, JsonElement> timeEntry : posEl.getAsJsonObject().entrySet()) {
                                    try {
                                        Keyframe k = new Keyframe();
                                        k.time = Float.parseFloat(timeEntry.getKey().trim());
                                        JsonObject kfObj = timeEntry.getValue().getAsJsonObject();
                                        JsonArray vec = kfObj.getAsJsonArray("vector");
                                        k.x = vec.get(0).getAsFloat();
                                        k.y = vec.get(1).getAsFloat();
                                        k.z = vec.get(2).getAsFloat();
                                        boneAnim.position.add(k);
                                    } catch (Exception ignored) {}
                                }
                            }
                        }
                        boneAnim.position.sort(Comparator.comparingDouble(k -> k.time));

                        // === СУЩЕСТВУЮЩЕЕ: Парсинг вращения (rotation) ===
                        if (boneObj.has("rotation")) {
                            JsonElement rotEl = boneObj.get("rotation");
                            if (rotEl.isJsonObject()) {
                                for (Map.Entry<String, JsonElement> timeEntry : rotEl.getAsJsonObject().entrySet()) {
                                    try {
                                        Keyframe k = new Keyframe();
                                        k.time = Float.parseFloat(timeEntry.getKey().trim());
                                        JsonObject kfObj = timeEntry.getValue().getAsJsonObject();
                                        JsonArray vec = kfObj.getAsJsonArray("vector");
                                        k.x = vec.get(0).getAsFloat();
                                        k.y = vec.get(1).getAsFloat();
                                        k.z = vec.get(2).getAsFloat();
                                        boneAnim.rotation.add(k);
                                    } catch (Exception ignored) { /* ignored */ }
                                }
                            }
                        }
                    }
                    boneAnim.rotation.sort(Comparator.comparingDouble(k -> k.time));
                    anim.bones.put(boneName, boneAnim);
                }
            }
            ANIMS.put(animName, anim);
        }
    }

    public static JsonAnim get(String name) {
        return ANIMS.get(name);
    }

    public static void applyAnim(JsonAnim anim, float timeSec, Map<String, ModelPart> parts) {
        if (anim == null) return;
        float t = timeSec;
        if (anim.loop) {
            t = t % anim.length;
        } else {
            t = MathHelper.clamp(t, 0, anim.length);
        }
        for (Map.Entry<String, BoneAnim> entry : anim.bones.entrySet()) {
            ModelPart part = parts.get(entry.getKey());
            if (part == null) continue;
            BoneAnim bone = entry.getValue();
            if (bone.rotation.isEmpty()) continue;

            Keyframe prev = bone.rotation.get(0);
            Keyframe next = bone.rotation.get(bone.rotation.size() - 1);
            for (int i = 0; i < bone.rotation.size() - 1; i++) {
                if (t >= bone.rotation.get(i).time && t <= bone.rotation.get(i+1).time) {
                    prev = bone.rotation.get(i);
                    next = bone.rotation.get(i+1);
                    break;
                }
            }
            float dt = next.time - prev.time;
            float progress = (dt > 0) ? (t - prev.time) / dt : 0;
            progress = MathHelper.clamp(progress, 0, 1);
            float s = progress * progress * (3 - 2 * progress);

            float rx = prev.x + (next.x - prev.x) * s;
            float ry = prev.y + (next.y - prev.y) * s;
            float rz = prev.z + (next.z - prev.z) * s;

            part.pitch = (float) Math.toRadians(rx);
            part.yaw   = (float) Math.toRadians(ry);
            part.roll  = (float) Math.toRadians(rz);
        }
    }

    // === НОВЫЙ МЕТОД: Интерполяция смещения для кости root ===
    public static float[] getRootOffset(JsonAnim anim, float timeSec) {
        if (anim == null || !anim.bones.containsKey("root")) return null;
        BoneAnim root = anim.bones.get("root");
        if (root.position.isEmpty()) return null;
        
        float t = timeSec;
        if (anim.loop) t = t % anim.length;
        else t = MathHelper.clamp(t, 0, anim.length);

        Keyframe prev = root.position.get(0);
        Keyframe next = root.position.get(root.position.size() - 1);
        for (int i = 0; i < root.position.size() - 1; i++) {
            if (t >= root.position.get(i).time && t <= root.position.get(i+1).time) {
                prev = root.position.get(i);
                next = root.position.get(i+1);
                break;
            }
        }
        float dt = next.time - prev.time;
        float progress = (dt > 0) ? (t - prev.time) / dt : 0;
        progress = MathHelper.clamp(progress, 0, 1);
        float s = progress * progress * (3 - 2 * progress);
        
        return new float[] {
            prev.x + (next.x - prev.x) * s,
            prev.y + (next.y - prev.y) * s,
            prev.z + (next.z - prev.z) * s
        };
    }

    private static String normalizeBoneName(String bbName) {
        switch (bbName) {
            case "leftForeArm": return "leftForeArm";
            case "rightForeArm": return "rightForeArm";
            case "leftShin": return "leftShin";
            case "rightShin": return "rightShin";
            case "root": return "root";
        }
        String lower = bbName.toLowerCase().replace("_", "").replace("biped", "");
        if (lower.equals("rightarm") || lower.equals("armright")) return "rightArm";
        if (lower.equals("leftarm") || lower.equals("armleft")) return "leftArm";
        if (lower.equals("rightleg") || lower.equals("legright")) return "rightLeg";
        if (lower.equals("leftleg") || lower.equals("legleft")) return "leftLeg";
        if (lower.equals("head")) return "head";
        if (lower.equals("body") || lower.equals("torso")) return "body";
        return bbName;
    }
}