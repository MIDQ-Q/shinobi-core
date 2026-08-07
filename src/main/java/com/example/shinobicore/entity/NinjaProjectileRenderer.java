package com.example.shinobicore.entity;

import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.util.Identifier;

public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {

    public NinjaProjectileRenderer(EntityRendererFactory.Context ctx) {
        super(ctx);
    }

    @Override
    public Identifier getTexture(NinjaProjectileEntity entity) {
        return null; // нет текстуры, только частицы
    }
}