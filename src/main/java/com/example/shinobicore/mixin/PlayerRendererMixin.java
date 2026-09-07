package com.example.shinobicore.mixin;

import com.example.shinobicore.client.render.ShinobiPlayerModel;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.render.entity.LivingEntityRenderer;
import net.minecraft.client.render.entity.PlayerEntityRenderer;
import net.minecraft.client.render.entity.model.EntityModelLayers;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Replaces the vanilla PlayerEntityModel with ShinobiPlayerModel
 * after PlayerEntityRenderer is constructed.
 * This gives us access to the extra bones (forearms, shins).
 */
@Mixin(PlayerEntityRenderer.class)
public abstract class PlayerRendererMixin
        extends LivingEntityRenderer<AbstractClientPlayerEntity, PlayerEntityModel<AbstractClientPlayerEntity>> {

    protected PlayerRendererMixin(EntityRendererFactory.Context ctx,
                                  PlayerEntityModel<AbstractClientPlayerEntity> model,
                                  float shadowRadius) {
        super(ctx, model, shadowRadius);
    }

    @Inject(method = "<init>", at = @At("RETURN"))
    private void shinobicore$swapModel(EntityRendererFactory.Context ctx, boolean slim, CallbackInfo ci) {
        this.model = new ShinobiPlayerModel<>(
            ctx.getPart(slim ? EntityModelLayers.PLAYER_SLIM : EntityModelLayers.PLAYER),
            slim
        );
    }
}