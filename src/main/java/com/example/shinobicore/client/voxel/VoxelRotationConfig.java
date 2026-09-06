package com.example.shinobicore.client.voxel;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.fabricmc.fabric.api.resource.SimpleSynchronousResourceReloadListener;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

public final class VoxelRotationConfig implements SimpleSynchronousResourceReloadListener {
    public static final VoxelRotationConfig INSTANCE = new VoxelRotationConfig();
    private static final Map<String, float[]> BY_MODEL = new HashMap<>();
    private static final float[] ZERO = {0f, 0f, 0f};

    @Override public Identifier getFabricId() { return new Identifier("shinobicore", "voxel_rotation"); }

    @Override
    public void reload(ResourceManager manager) {
        BY_MODEL.clear();
        Map<Identifier, Resource> found = manager.findResources("jutsu", id -> id.getPath().endsWith(".json"));
        for (Map.Entry<Identifier, Resource> e : found.entrySet()) {
            try (InputStream in = e.getValue().getInputStream()) {
                JsonObject root = JsonParser.parseReader(new InputStreamReader(in, StandardCharsets.UTF_8)).getAsJsonObject();
                if (!root.has("visual") || !root.get("visual").isJsonObject()) continue;
                JsonObject vis = root.getAsJsonObject("visual");
                if (!vis.has("voxelModel") || !vis.get("voxelModel").isJsonPrimitive()) continue;
                String model = vis.get("voxelModel").getAsString();
                if (model.isEmpty()) continue;
                if (!vis.has("rotationOffset") || !vis.get("rotationOffset").isJsonArray()) continue;
                JsonArray a = vis.getAsJsonArray("rotationOffset");
                if (a.size() < 3) continue;
                BY_MODEL.put(model, new float[]{a.get(0).getAsFloat(), a.get(1).getAsFloat(), a.get(2).getAsFloat()});
            } catch (Exception ex) {
                ShinobiCore.LOGGER.warn("[VoxelRot] bad visual in {}: {}", e.getKey(), ex.toString());
            }
        }
        ShinobiCore.LOGGER.info("[VoxelRot] rotation offsets for {} model(s)", BY_MODEL.size());
    }

    public static float[] get(String model) {
        float[] o = BY_MODEL.get(model);
        return o != null ? o : ZERO;
    }
}