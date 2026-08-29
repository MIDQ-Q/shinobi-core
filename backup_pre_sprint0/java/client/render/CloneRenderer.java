package com.example.shinobicore.client.render;

import com.example.shinobicore.entity.CloneEntity;
import net.minecraft.client.render.entity.EntityRendererFactory;
import software.bernie.geckolib.renderer.GeoEntityRenderer;

/**
 * GeckoLib renderer for CloneEntity.
 * HLD: Blueprint (static decoy clones)
 */
public class CloneRenderer extends GeoEntityRenderer<CloneEntity> {
    public CloneRenderer(EntityRendererFactory.Context renderManager) {
        super(renderManager, new CloneModel());
        this.shadowRadius = 0.4f;
    }
}