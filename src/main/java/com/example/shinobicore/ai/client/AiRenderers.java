package com.example.shinobicore.ai.client;

import com.example.shinobicore.ai.AiEntities;
import com.example.shinobicore.ai.RogueNinjaEntity;
import com.example.shinobicore.ai.SummonCloneEntity;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;
import net.minecraft.client.render.entity.BipedEntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.render.entity.LivingEntityRenderer;
import net.minecraft.client.render.entity.model.EntityModelLayers;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.client.render.entity.model.WolfEntityModel;
import net.minecraft.util.Identifier;

/**
 * Entity renderers. Future Blockbench models plug in here:
 * add a case in the registry map and a ModelPart-based renderer.
 */
public class AiRenderers {

    public static void register() {
        EntityRendererRegistry.register(AiEntities.SUMMON_CLONE, SummonCloneRenderer::new);
        EntityRendererRegistry.register(AiEntities.ROGUE_NINJA, RogueNinjaRenderer::new);
    }

    private static class SummonCloneRenderer extends LivingEntityRenderer<SummonCloneEntity, WolfEntityModel<SummonCloneEntity>> {
        private static final Identifier TEXTURE = new Identifier("shinobicore", "textures/entity/summon_clone.png");

        SummonCloneRenderer(EntityRendererFactory.Context ctx) {
            super(ctx, new WolfEntityModel<>(ctx.getPart(EntityModelLayers.WOLF)), 0.7f);
        }

        @Override
        public Identifier getTexture(SummonCloneEntity entity) { return TEXTURE; }
    }

    private static class RogueNinjaRenderer extends BipedEntityRenderer<RogueNinjaEntity, PlayerEntityModel<RogueNinjaEntity>> {
        private static final Identifier TEXTURE = new Identifier("shinobicore", "textures/entity/rogue_ninja.png");

        RogueNinjaRenderer(EntityRendererFactory.Context ctx) {
            super(ctx, new PlayerEntityModel<>(ctx.getPart(EntityModelLayers.PLAYER), false), 0.5f);
        }

        @Override
        public Identifier getTexture(RogueNinjaEntity entity) { return TEXTURE; }
    }
}