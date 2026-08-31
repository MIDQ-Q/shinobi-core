package com.example.shinobicore.modules.combat.render;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import net.fabricmc.fabric.api.client.rendering.v1.LivingEntityFeatureRendererRegistrationCallback;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.feature.FeatureRenderer;
import net.minecraft.client.render.entity.feature.FeatureRendererContext;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.player.PlayerEntity;

public class SheathFeatureRenderer extends FeatureRenderer<PlayerEntity, PlayerEntityModel<PlayerEntity>> {
    
    public SheathFeatureRenderer(FeatureRendererContext<PlayerEntity, PlayerEntityModel<PlayerEntity>> context) {
        super(context);
    }

    @Override
    public void render(MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light, 
                       PlayerEntity entity, float limbAngle, float limbDistance, float tickDelta, 
                       float animationProgress, float headYaw, float headPitch) {
        
        CombatComponent comp = CombatComponentKey.KEY.getNullable(entity);
        if (comp == null || !comp.isSheathed()) {
            return; // Do not render sheath if weapon is drawn
        }

        // TODO: Integrate with GeckoLibAdapter or custom model here.
        // Example: GeckoLibAdapter.renderSheathModel(matrices, vertexConsumers, light, entity, tickDelta);
        
        // Stub: Just log once per session to prove it's hooked (in real code, remove this)
        // ShinobiLogger.module("combat", "Rendering sheath for " + entity.getName().getString());
    }

    public static void register() {
        LivingEntityFeatureRendererRegistrationCallback.EVENT.register((entityType, renderer, registrationHelper, context) -> {
            if (entityType == net.minecraft.entity.EntityType.PLAYER) {
                registrationHelper.register(new SheathFeatureRenderer((FeatureRendererContext<PlayerEntity, PlayerEntityModel<PlayerEntity>>) renderer));
                ShinobiLogger.module("combat", "SheathFeatureRenderer registered for PlayerEntity");
            }
        });
    }
}