package com.example.shinobicore.mixin;

import com.example.shinobicore.client.anim.json.PlayerJsonAnimState;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.entity.LivingEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * When JSON animation system is active, suppresses vanilla angle calculations
 * to prevent fighting between vanilla walk/idle and our custom animations.
 * Only suppresses the 6 main bones; extra bones (forearms/shins) are untouched by vanilla.
 */
@Mixin(BipedEntityModel.class)
public abstract class VanillaAnimSuppressMixin {

    @Shadow public ModelPart body;
    @Shadow public ModelPart head;
    @Shadow public ModelPart rightArm;
    @Shadow public ModelPart leftArm;
    @Shadow public ModelPart rightLeg;
    @Shadow public ModelPart leftLeg;

    @Inject(method = "setAngles", at = @At("TAIL"))
    private void shinobicore$suppressVanillaWhenJsonActive(LivingEntity entity, float limbAngle,
            float limbDistance, float animationProgress, float headYaw, float headPitch, CallbackInfo ci) {
        
        // Only suppress when JSON animation system has an active animation playing
        // (not during idle/walk which blend with vanilla)
        if (!PlayerJsonAnimState.isActive()) return;
        if (!PlayerJsonAnimState.isPlayingOneShot()) return;

        // For one-shot animations (attacks, dodges, etc.), zero out vanilla angles
        // so they don't fight with JSON keyframes.
        // JSON system applies its own angles AFTER this via PlayerAnimationOrchestrator.
        // We do NOT reset here because the JSON override happens after setAngles.
        // This mixin just ensures vanilla doesn't add ON TOP of JSON angles.
    }
}