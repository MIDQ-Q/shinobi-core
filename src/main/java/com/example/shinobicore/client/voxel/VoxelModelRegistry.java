package com.example.shinobicore.client.voxel;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.fabricmc.fabric.api.resource.SimpleSynchronousResourceReloadListener;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.*;

public final class VoxelModelRegistry implements SimpleSynchronousResourceReloadListener {
    public static final VoxelModelRegistry INSTANCE = new VoxelModelRegistry();
    private static final Map<String, VoxelModel> MODELS = new HashMap<>();

    @Override public Identifier getFabricId() { return new Identifier("shinobicore", "voxel_models"); }

    @Override
    public void reload(ResourceManager manager) {
        MODELS.clear();
        Map<Identifier, Resource> found = manager.findResources("voxels",
            id -> id.getPath().endsWith(".json") || id.getPath().endsWith(".bbmodel"));
        for (Map.Entry<Identifier, Resource> e : found.entrySet()) {
            Identifier id = e.getKey();
            try (InputStream in = e.getValue().getInputStream()) {
                JsonObject root = JsonParser.parseReader(new InputStreamReader(in, StandardCharsets.UTF_8)).getAsJsonObject();
                String p = id.getPath();
                String base = p.substring("voxels/".length());
                boolean bb = p.endsWith(".bbmodel");
                String name = (bb ? base.substring(0, base.length() - 8) : base.substring(0, base.length() - 5))
                    .toLowerCase().replace(' ', '_');
                List<VoxelModel.TextureRef> textures = parseTextures(root, name);
                List<VoxelModel.Element> elements = new ArrayList<>();
                JsonArray arr = root.has("elements") && root.get("elements").isJsonArray()
                    ? root.getAsJsonArray("elements")
                    : (root.has("voxels") && root.get("voxels").isJsonArray() ? root.getAsJsonArray("voxels") : null);
                collect(arr, elements, bb, name);
                MODELS.put(name, build(root, name, elements, textures));
                ShinobiCore.LOGGER.info("[Voxel] Loaded '{}' ({} elements, {} textures) [{}]",
                    name, elements.size(), textures.size(), bb ? "bbmodel" : "json");
            } catch (Exception ex) {
                ShinobiCore.LOGGER.error("[Voxel] Failed to load " + id + " : " + ex, ex);
            }
        }
        ShinobiCore.LOGGER.info("[Voxel] Total models: {}", MODELS.size());
    }

    public static VoxelModel get(String n) { return n == null ? null : MODELS.get(n); }

    private static VoxelModel.TextureRef emptyTex(int i) {
        return new VoxelModel.TextureRef("tex_" + i, "", "t" + i, 16, 16);
    }

    private static List<VoxelModel.TextureRef> parseTextures(JsonObject root, String name) {
        List<VoxelModel.TextureRef> out = new ArrayList<>();
        if (!root.has("textures") || !root.get("textures").isJsonArray()) return out;
        int i = 0;
        for (JsonElement el : root.getAsJsonArray("textures")) {
            try {
                if (!el.isJsonObject()) { out.add(emptyTex(i)); i++; continue; }
                JsonObject t = el.getAsJsonObject();
                out.add(new VoxelModel.TextureRef(
                    t.has("name") && t.get("name").isJsonPrimitive() ? t.get("name").getAsString() : ("tex_" + i),
                    t.has("source") && t.get("source").isJsonPrimitive() ? t.get("source").getAsString() : "",
                    t.has("uuid") && t.get("uuid").isJsonPrimitive() ? t.get("uuid").getAsString() : ("t" + i),
                    t.has("width") && t.get("width").isJsonPrimitive() ? t.get("width").getAsInt() : 16,
                    t.has("height") && t.get("height").isJsonPrimitive() ? t.get("height").getAsInt() : 16));
            } catch (Exception ex) { out.add(emptyTex(i)); }
            i++;
        }
        return out;
    }

    private static void collect(JsonArray arr, List<VoxelModel.Element> out, boolean bb, String name) {
        if (arr == null) return;
        for (JsonElement el : arr) {
            if (el == null || !el.isJsonObject()) continue;
            JsonObject o = el.getAsJsonObject();
            try {
                String type = o.has("type") && o.get("type").isJsonPrimitive() ? o.get("type").getAsString() : "cube";
                if ("group".equals(type)) continue;
                if ("mesh".equals(type)) { out.add(parseMesh(o, bb)); continue; }
                VoxelModel.CubeElement c = parseCube(o, bb);
                if (c != null) out.add(c);
            } catch (Exception ex) {
                ShinobiCore.LOGGER.warn("[Voxel] {} skip bad element: {}", name, ex.toString());
            }
        }
    }

    private static VoxelModel.CubeElement parseCube(JsonObject o, boolean bb) {
        if (!o.has("from") || !o.has("to")) return null;
        if (!o.get("from").isJsonArray() || !o.get("to").isJsonArray()) return null;
        float[] f = readVec(o.getAsJsonArray("from"));
        float[] t = readVec(o.getAsJsonArray("to"));
        if (f == null || t == null) return null;
        if (bb) { div16(f); div16(t); }
        Map<String, VoxelModel.Face> faces = new HashMap<>();
        if (o.has("faces") && o.get("faces").isJsonObject()) {
            JsonObject fo = o.getAsJsonObject("faces");
            for (String fn : fo.keySet()) {
                JsonElement fe = fo.get(fn);
                if (fe == null || !fe.isJsonObject()) continue;
                JsonObject fce = fe.getAsJsonObject();
                if (fce.has("uv") && fce.get("uv").isJsonArray()) {
                    float[] uv = readUV(fce.getAsJsonArray("uv"));
                    if (uv != null) faces.put(fn, new VoxelModel.Face(uv,
                        fce.has("texture") && fce.get("texture").isJsonPrimitive() ? fce.get("texture").getAsInt() : 0));
                }
            }
        }
        VoxelModel.Rotation rot = null;
        if (o.has("rotation") && o.get("rotation").isJsonObject()) {
            JsonObject r = o.getAsJsonObject("rotation");
            float[] origin = r.has("origin") && r.get("origin").isJsonArray() ? readVec(r.getAsJsonArray("origin")) : null;
            if (bb && origin != null) div16(origin);
            rot = new VoxelModel.Rotation(
                r.has("axis") && r.get("axis").isJsonPrimitive() ? r.get("axis").getAsString() : "y",
                r.has("angle") && r.get("angle").isJsonPrimitive() ? r.get("angle").getAsFloat() : 0f,
                origin != null ? origin : new float[]{0.5f, 0.5f, 0.5f});
        }
        float alpha = o.has("alpha") && o.get("alpha").isJsonPrimitive() ? o.get("alpha").getAsFloat() : 1f;
        return new VoxelModel.CubeElement(f, t, parseColor(o.get("color")), faces, rot, alpha);
    }

    private static VoxelModel.MeshElement parseMesh(JsonObject o, boolean bb) {
        List<float[]> verts = new ArrayList<>();
        Map<String, Integer> keyIdx = new HashMap<>();
        if (o.has("vertices")) {
            JsonElement ve = o.get("vertices");
            if (ve.isJsonObject()) {
                for (Map.Entry<String, JsonElement> en : ve.getAsJsonObject().entrySet()) {
                    if (en.getValue() != null && en.getValue().isJsonArray()) {
                        float[] vv = readVec(en.getValue().getAsJsonArray());
                        if (vv != null) { if (bb) div16(vv); keyIdx.put(en.getKey(), verts.size()); verts.add(vv); }
                    }
                }
            } else if (ve.isJsonArray()) {
                for (JsonElement jv : ve.getAsJsonArray()) {
                    if (jv.isJsonArray()) {
                        float[] vv = readVec(jv.getAsJsonArray());
                        if (vv != null) { if (bb) div16(vv); verts.add(vv); }
                    }
                }
            }
        }
        List<VoxelModel.MeshFace> faces = new ArrayList<>();
        if (o.has("faces")) {
            JsonElement fe = o.get("faces");
            if (fe.isJsonArray()) {
                for (JsonElement jf : fe.getAsJsonArray()) {
                    if (!jf.isJsonObject()) continue;
                    JsonObject f = jf.getAsJsonObject();
                    if (!f.has("indices") || !f.has("uv")) continue;
                    JsonArray ia = f.getAsJsonArray("indices");
                    JsonArray ua = f.getAsJsonArray("uv");
                    int[] idx = new int[ia.size()];
                    boolean ok = true;
                    for (int k = 0; k < ia.size(); k++) {
                        idx[k] = ia.get(k).getAsInt();
                        if (idx[k] < 0 || idx[k] >= verts.size()) ok = false;
                    }
                    if (!ok || ua.size() < ia.size()) continue;
                    float[][] uv = new float[ua.size()][];
                    for (int k = 0; k < ua.size(); k++) {
                        uv[k] = (ua.get(k).isJsonArray() && ua.get(k).getAsJsonArray().size() >= 2)
                            ? new float[]{ua.get(k).getAsJsonArray().get(0).getAsFloat(), ua.get(k).getAsJsonArray().get(1).getAsFloat()}
                            : new float[]{0, 0};
                    }
                    faces.add(new VoxelModel.MeshFace(idx, uv,
                        f.has("texture") && f.get("texture").isJsonPrimitive() ? f.get("texture").getAsInt() : 0));
                }
            } else if (fe.isJsonObject()) {
                // FIX: Blockbench stores faces.vertices as JsonArray of string keys!
                for (Map.Entry<String, JsonElement> en : fe.getAsJsonObject().entrySet()) {
                    if (en.getValue() == null || !en.getValue().isJsonObject()) continue;
                    JsonObject f = en.getValue().getAsJsonObject();
                    if (!f.has("vertices") || !f.get("vertices").isJsonArray()) continue;
                    JsonArray vertKeys = f.getAsJsonArray("vertices");
                    if (vertKeys.size() < 3) continue;
                    
                    JsonObject uvMap = f.has("uv") && f.get("uv").isJsonObject() ? f.getAsJsonObject("uv") : new JsonObject();
                    
                    int[] idx = new int[vertKeys.size()];
                    float[][] uv = new float[vertKeys.size()][];
                    
                    for (int k = 0; k < vertKeys.size(); k++) {
                        String key = vertKeys.get(k).getAsString();
                        idx[k] = keyIdx.getOrDefault(key, 0);
                        
                        if (uvMap.has(key) && uvMap.get(key).isJsonArray()) {
                            JsonArray uvArr = uvMap.getAsJsonArray(key);
                            uv[k] = new float[]{uvArr.get(0).getAsFloat(), uvArr.get(1).getAsFloat()};
                        } else {
                            uv[k] = new float[]{0, 0};
                        }
                    }
                    
                    int tex = f.has("texture") && f.get("texture").isJsonPrimitive() ? f.get("texture").getAsInt() : 0;
                    faces.add(new VoxelModel.MeshFace(idx, uv, tex));
                }
            }
        }
        return new VoxelModel.MeshElement(verts.toArray(new float[0][]), faces.toArray(new VoxelModel.MeshFace[0]));
    }

    private static VoxelModel build(JsonObject root, String name, List<VoxelModel.Element> elements, List<VoxelModel.TextureRef> textures) {
        float minX=99,minY=99,minZ=99,maxX=-99,maxY=-99,maxZ=-99;
        for (VoxelModel.Element e : elements) {
            if (e instanceof VoxelModel.CubeElement c) {
                minX=Math.min(minX,c.from()[0]); maxX=Math.max(maxX,c.to()[0]);
                minY=Math.min(minY,c.from()[1]); maxY=Math.max(maxY,c.to()[1]);
                minZ=Math.min(minZ,c.from()[2]); maxZ=Math.max(maxZ,c.to()[2]);
            } else if (e instanceof VoxelModel.MeshElement m) {
                for (float[] v : m.vertices()) {
                    minX=Math.min(minX,v[0]); maxX=Math.max(maxX,v[0]);
                    minY=Math.min(minY,v[1]); maxY=Math.max(maxY,v[1]);
                    minZ=Math.min(minZ,v[2]); maxZ=Math.max(maxZ,v[2]);
                }
            }
        }
        String particle = root.has("particle") && root.get("particle").isJsonPrimitive() ? root.get("particle").getAsString() : "";
        String pcolor = root.has("particleColor") && root.get("particleColor").isJsonPrimitive() ? root.get("particleColor").getAsString() : "#FF6600";
        int prate = root.has("particleRate") && root.get("particleRate").isJsonPrimitive() ? root.get("particleRate").getAsInt() : 1;
        float prad = root.has("particleRadius") && root.get("particleRadius").isJsonPrimitive() ? root.get("particleRadius").getAsFloat() : 0.5f;
        VoxelModel.AnimDef anim = parseAnim(root);
        return new VoxelModel(name, elements, textures, (minX+maxX)/2f, (minY+maxY)/2f, (minZ+maxZ)/2f, particle, pcolor, prate, prad, anim);
    }

    private static VoxelModel.AnimDef parseAnim(JsonObject root) {
        if (!root.has("anim") || !root.get("anim").isJsonObject()) return new VoxelModel.AnimDef(0,0,0,0,0,0,0);
        JsonObject a = root.getAsJsonObject("anim");
        float sx = 0, sy = 0, sz = 0;
        if (a.has("spin") && a.get("spin").isJsonArray()) {
            JsonArray s = a.getAsJsonArray("spin");
            if (s.size() >= 3) { sx = s.get(0).getAsFloat(); sy = s.get(1).getAsFloat(); sz = s.get(2).getAsFloat(); }
        }
        float pulse = a.has("pulse") ? a.get("pulse").getAsFloat() : 0;
        float pulseSpeed = a.has("pulseSpeed") ? a.get("pulseSpeed").getAsFloat() : 3f;
        float bob = a.has("bob") ? a.get("bob").getAsFloat() : 0;
        float bobSpeed = a.has("bobSpeed") ? a.get("bobSpeed").getAsFloat() : 2f;
        return new VoxelModel.AnimDef(sx, sy, sz, pulse, pulseSpeed, bob, bobSpeed);
    }

    private static void div16(float[] a) { for (int i = 0; i < a.length; i++) a[i] /= 16f; }
    private static float[] readVec(JsonArray a) {
        if (a == null || a.size() < 3) return null;
        return new float[]{a.get(0).getAsFloat(), a.get(1).getAsFloat(), a.get(2).getAsFloat()};
    }
    private static float[] readUV(JsonArray a) {
        if (a == null || a.size() < 4) return null;
        return new float[]{a.get(0).getAsFloat(), a.get(1).getAsFloat(), a.get(2).getAsFloat(), a.get(3).getAsFloat()};
    }
    private static int parseColor(JsonElement el) {
        if (el != null && el.isJsonPrimitive() && el.getAsJsonPrimitive().isString()) {
            String s = el.getAsString();
            if (s.startsWith("#") && s.length() >= 7) {
                try { return (int) Long.parseLong(s.substring(1, 7), 16); } catch (Exception ignored) {}
            }
        }
        return 0xFF6600;
    }
}