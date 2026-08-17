package com.example.shinobicore.client.render;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.util.Identifier;

/**
 * S5-07: Shader compatibility manager.
 * Detects Iris/Sodium and adjusts rendering to prevent:
 * - Black squares with transparency
 * - Depth buffer issues
 * - Incorrect render order
 * - Missing glow/emissive effects
 */
public class ShaderCompatibilityManager {

    private static boolean irisLoaded = false;
    private static boolean sodiumLoaded = false;
    private static boolean initialized = false;

    public static void init() {
        if (initialized) return;
        initialized = true;
        irisLoaded = FabricLoader.getInstance().isModLoaded("iris");
        sodiumLoaded = FabricLoader.getInstance().isModLoaded("sodium");
        ShinobiCore.LOGGER.info("[SHADER] Iris: {}, Sodium: {}", irisLoaded, sodiumLoaded);
    }

    public static boolean isIrisLoaded() {
        if (!initialized) init();
        return irisLoaded;
    }

    public static boolean isSodiumLoaded() {
        if (!initialized) init();
        return sodiumLoaded;
    }

    /**
     * Get VFX render layer compatible with current shader setup.
     * Iris requires EntityTranslucentCull to avoid black squares.
     */
    public static RenderLayer getVfxLayer(Identifier texture) {
        if (!initialized) init();
        if (irisLoaded) {
            return RenderLayer.getEntityTranslucentCull(texture);
        }
        return RenderLayer.getEntityTranslucent(texture);
    }

    /**
     * Get emissive render layer.
     * With shaders, emissive uses same layer but with max light.
     */
    public static RenderLayer getEmissiveLayer(Identifier texture) {
        if (!initialized) init();
        if (irisLoaded) {
            return RenderLayer.getEntityTranslucentCull(texture);
        }
        return RenderLayer.getEntityTranslucent(texture);
    }

    /**
     * Recommended particle limit based on shader presence.
     * Shaders are GPU-expensive, so reduce particle count.
     */
    public static int getParticleLimit() {
        if (!initialized) init();
        if (irisLoaded && sodiumLoaded) return 300;
        if (irisLoaded) return 350;
        return 400;
    }

    /**
     * Whether to use alternative blending for transparency.
     * Iris handles alpha blending differently.
     */
    public static boolean needsAlternativeBlending() {
        if (!initialized) init();
        return irisLoaded;
    }

    /**
     * Whether double-sided rendering is needed.
     * With shaders, backface culling can cause artifacts.
     */
    public static boolean needsDoubleSided() {
        if (!initialized) init();
        return irisLoaded;
    }
}