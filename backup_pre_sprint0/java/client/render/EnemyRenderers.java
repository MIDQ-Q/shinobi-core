package com.example.shinobicore.client.render;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.entity.enemy.NinjaEnemyRenderer;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;

/**
 * Client-side GeckoLib renderer registration (enemy + clone).
 * Idempotent: safe to call multiple times.
 * HLD: Section 5 / 7
 */
public final class EnemyRenderers {

    private static boolean initialized = false;

    private EnemyRenderers() {}

    public static void init() {
        if (initialized) return;
        initialized = true;
        EntityRendererRegistry.register(ModEntities.NINJA_ENEMY, NinjaEnemyRenderer::new);
        EntityRendererRegistry.register(ModEntities.CLONE, CloneRenderer::new);
        ShinobiCore.LOGGER.info("EnemyRenderers registered (enemy + clone)");
    }
}