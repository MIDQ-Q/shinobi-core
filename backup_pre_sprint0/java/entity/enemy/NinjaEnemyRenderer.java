package com.example.shinobicore.entity.enemy;

import net.minecraft.client.render.entity.EntityRendererFactory;
import software.bernie.geckolib.renderer.GeoEntityRenderer;

/**
 * GeckoLib entity renderer for the rogue ninja.
 * HLD: Section 5
 */
public class NinjaEnemyRenderer extends GeoEntityRenderer<NinjaEnemyEntity> {

    public NinjaEnemyRenderer(EntityRendererFactory.Context renderManager) {
        super(renderManager, new NinjaEnemyModel());
        this.shadowRadius = 0.4f;
    }
}