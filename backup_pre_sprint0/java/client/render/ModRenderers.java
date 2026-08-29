package com.example.shinobicore.client.render;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.ModEntities;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;

/**
 * Client-side renderer registration.
 * HLD: Section 2.4
 */
public final class ModRenderers {

    private ModRenderers() {}

    public static void init() {
        EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);
        ShinobiCore.LOGGER.info("ModRenderers registered");
    }
}