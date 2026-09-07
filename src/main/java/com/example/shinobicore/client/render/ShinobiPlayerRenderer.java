package com.example.shinobicore.client.render;

import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.render.entity.PlayerEntityRenderer;
import net.minecraft.client.render.entity.model.EntityModelLayers;
import net.minecraft.util.Identifier;

/**
 * Custom player renderer that uses ShinobiPlayerModel.
 * Uses the player's standard skin texture.
 */
public class ShinobiPlayerRenderer extends PlayerEntityRenderer {

    public ShinobiPlayerRenderer(EntityRendererFactory.Context ctx, boolean slim) {
        super(ctx, slim);
        // Replace the model with our custom 11-bone model
        this.model = new ShinobiPlayerModel<>(
            ctx.getPart(slim ? EntityModelLayers.PLAYER_SLIM : EntityModelLayers.PLAYER),
            slim
        );
    }

    /**
     * Use the player's standard skin texture.
     * In 1.20.1 Yarn: getSkinTexture() returns Identifier directly.
     */
    @Override
    public Identifier getTexture(AbstractClientPlayerEntity entity) {
        return entity.getSkinTexture();
    }
}