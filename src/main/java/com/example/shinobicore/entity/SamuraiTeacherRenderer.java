package com.example.shinobicore.entity;

import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.render.entity.MobEntityRenderer;
import net.minecraft.client.render.entity.model.EntityModelLayers;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.util.Identifier;

/**
 * S7-08: Renderer for samurai teacher NPC.
 * Uses player model with samurai skin texture.
 */
public class SamuraiTeacherRenderer extends MobEntityRenderer<SamuraiTeacherEntity, PlayerEntityModel<SamuraiTeacherEntity>> {

    private static final Identifier TEXTURE = new Identifier("shinobicore", "textures/entity/samurai_teacher.png");

    public SamuraiTeacherRenderer(EntityRendererFactory.Context ctx) {
        super(ctx, new PlayerEntityModel<>(ctx.getPart(EntityModelLayers.PLAYER), false), 0.5f);
    }

    @Override
    public Identifier getTexture(SamuraiTeacherEntity entity) {
        return TEXTURE;
    }
}