package com.example.shinobicore.mixin;

import com.example.shinobicore.client.combat.HitStopManager;
import com.example.shinobicore.client.anim.PlayerAnimationOrchestrator;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.entity.LivingEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Phase 3.5: All animation logic moved to PlayerAnimationOrchestrator.
 * This mixin is now a thin delegation layer only.
 */
@Mixin(BipedEntityModel.class)
public abstract class PlayerRenderAnimationMixin {

    @Inject(method = "setAngles", at = @At("TAIL"))
    private void shinobicore_applyAnimations(LivingEntity entity, float limbAngle, float limbDistance,
            float animationProgress, float headYaw, float headPitch,
            CallbackInfo ci) {
        if (!(entity instanceof AbstractClientPlayerEntity player)) return;

        if (HitStopManager.isFrozen(entity.getId())) {
            return;
        }

        PlayerAnimationOrchestrator.apply(
            player,
            (BipedEntityModel<?>) (Object) this,
            limbAngle,
            limbDistance,
            animationProgress
        );
    }
}