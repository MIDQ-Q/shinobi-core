package com.example.shinobicore.client.render;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.fabricmc.fabric.api.resource.ResourceManagerHelper;
import net.fabricmc.fabric.api.resource.SimpleSynchronousResourceReloadListener;
import net.minecraft.item.ItemStack;
import net.minecraft.registry.Registries;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.resource.ResourceType;
import net.minecraft.util.Identifier;
import org.joml.Vector3f;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Data-driven weapon visuals (client side).
 * Files: assets/shinobicore/weapon_visuals/<item_path>.json
 * One file per weapon. Reloaded with /reload or F3+T.
 */
public final class WeaponVisualRegistry implements SimpleSynchronousResourceReloadListener {
    public static final WeaponVisualRegistry INSTANCE = new WeaponVisualRegistry();
    private static final Map<String, Visual> BY_ITEM_PATH = new HashMap<>();

    public static final class Visual {
        public String item = "";
        public String model = "";
        public boolean glint = false;
        public boolean particlesEnabled = true;
        public String particleType = "dust";
        public String color = "#FFFFFF";
        public int rate = 2;
        public int intervalTicks = 2;
        public float spread = 0.25f;
        public final List<String> slashAnimations = new ArrayList<>();

        public Vector3f colorVec() {
            try {
                String h = color.startsWith("#") ? color.substring(1) : color;
                int n = (int) Long.parseLong(h, 16);
                return new Vector3f(((n >> 16) & 255) / 255f, ((n >> 8) & 255) / 255f, (n & 255) / 255f);
            } catch (Exception e) {
                return new Vector3f(1f, 1f, 1f);
            }
        }
    }

    private WeaponVisualRegistry() {}

    public static void register() {
        ResourceManagerHelper.get(ResourceType.CLIENT_RESOURCES).registerReloadListener(INSTANCE);
    }

    @Override
    public Identifier getFabricId() {
        return new Identifier("shinobicore", "weapon_visuals");
    }

    @Override
    public void reload(ResourceManager manager) {
        BY_ITEM_PATH.clear();
        Map<Identifier, Resource> found = manager.findResources(
                "weapon_visuals", id -> id.getPath().endsWith(".json"));
        for (Map.Entry<Identifier, Resource> e : found.entrySet()) {
            try (InputStream in = e.getValue().getInputStream()) {
                JsonObject o = JsonParser.parseReader(
                        new InputStreamReader(in, StandardCharsets.UTF_8)).getAsJsonObject();
                Visual v = new Visual();
                if (o.has("item")) v.item = o.get("item").getAsString();
                if (o.has("model")) v.model = o.get("model").getAsString();
                if (o.has("glint")) v.glint = o.get("glint").getAsBoolean();
                if (o.has("particles") && o.get("particles").isJsonObject()) {
                    JsonObject p = o.getAsJsonObject("particles");
                    v.particlesEnabled = !p.has("enabled") || p.get("enabled").getAsBoolean();
                    if (p.has("type")) v.particleType = p.get("type").getAsString();
                    if (p.has("color")) v.color = p.get("color").getAsString();
                    if (p.has("rate")) v.rate = Math.max(1, p.get("rate").getAsInt());
                    if (p.has("intervalTicks")) v.intervalTicks = Math.max(1, p.get("intervalTicks").getAsInt());
                    if (p.has("spread")) v.spread = p.get("spread").getAsFloat();
                }
                if (o.has("slashAnimations") && o.get("slashAnimations").isJsonArray()) {
                    o.getAsJsonArray("slashAnimations").forEach(el -> v.slashAnimations.add(el.getAsString()));
                }
                String path = v.item.contains(":")
                        ? v.item.substring(v.item.indexOf(':') + 1) : v.item;
                BY_ITEM_PATH.put(path, v);
                ShinobiCore.LOGGER.info("[WeaponVisual] Loaded: {} (glint={}, particles={}, slashAnims={})",
                        v.item, v.glint, v.particlesEnabled, v.slashAnimations.size());
            } catch (Exception ex) {
                ShinobiCore.LOGGER.error("[WeaponVisual] Failed to load " + e.getKey(), ex);
            }
        }
        ShinobiCore.LOGGER.info("[WeaponVisual] Total visuals: {}", BY_ITEM_PATH.size());
    }

    public static Visual get(ItemStack stack) {
        if (stack == null || stack.isEmpty()) return null;
        Identifier id = Registries.ITEM.getId(stack.getItem());
        return id == null ? null : BY_ITEM_PATH.get(id.getPath());
    }

    public static boolean hasGlint(ItemStack stack) {
        Visual v = get(stack);
        return v != null && v.glint;
    }

    public static String getSlashAnim(ItemStack stack, int step) {
        Visual v = get(stack);
        if (v == null || step < 0 || step >= v.slashAnimations.size()) return null;
        String name = v.slashAnimations.get(step);
        return com.example.shinobicore.client.anim.json.JsonAnimLibrary.get(name) != null ? name : null;
    }
}