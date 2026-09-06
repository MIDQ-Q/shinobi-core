package com.example.shinobicore.client.voxel;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.texture.NativeImage;
import net.minecraft.client.texture.NativeImageBackedTexture;
import net.minecraft.util.Identifier;

import java.io.ByteArrayInputStream;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

public final class VoxelTextureManager {
    private static final Map<String, Identifier> TEXTURES = new HashMap<>();
    private static final Map<String, int[]> DIMS = new HashMap<>();
    private VoxelTextureManager() {}

    public static Identifier getTexture(String modelName, int idx) { return TEXTURES.get(modelName + "_" + idx); }
    public static int[] getDims(String modelName, int idx) {
        int[] d = DIMS.get(modelName + "_" + idx);
        return d != null ? d : new int[]{16, 16};
    }

    public static void register(String modelName, int idx, String base64Source, int w, int h) {
        String key = modelName + "_" + idx;
        DIMS.put(key, new int[]{w, h});
        if (TEXTURES.containsKey(key)) return;
        if (base64Source == null || !base64Source.startsWith("data:image")) return;
        try {
            String data = base64Source.split(",")[1];
            byte[] bytes = Base64.getDecoder().decode(data);
            NativeImage img = NativeImage.read(new ByteArrayInputStream(bytes));
            NativeImageBackedTexture tex = new NativeImageBackedTexture(img);
            Identifier id = new Identifier("shinobicore", "voxel/" + key);
            MinecraftClient.getInstance().getTextureManager().registerTexture(id, tex);
            TEXTURES.put(key, id);
        } catch (Exception e) {
            System.err.println("[VoxelTexture] Failed " + key + ": " + e.getMessage());
        }
    }
}