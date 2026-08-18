package com.example.shinobicore.entity.enemy;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.client.render.entity.BipedEntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.render.entity.model.EntityModelLayers;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.util.Identifier;

/**
 * S9-01: Renderer for ninja enemies.
 * Uses player model with shinobi skin texture.
 * Skin file: assets/shinobicore/textures/entity/shinobi.png (64x64)
 */
public class EnemyRenderer extends BipedEntityRenderer<NinjaEnemyEntity, PlayerEntityModel<NinjaEnemyEntity>> {
    private static final Identifier SHINOBI_TEXTURE =
        new Identifier(ShinobiCore.MOD_ID, "textures/entity/shinobi.png");

    public EnemyRenderer(EntityRendererFactory.Context context) {
        super(context, new PlayerEntityModel<>(context.getPart(EntityModelLayers.PLAYER), false), 0.5f);
    }

    @Override
    public Identifier getTexture(NinjaEnemyEntity entity) {
        return SHINOBI_TEXTURE;
    }
}