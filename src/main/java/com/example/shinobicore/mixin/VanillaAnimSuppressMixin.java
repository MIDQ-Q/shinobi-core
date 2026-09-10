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
 * When a JSON one-shot animation is active, zeroes out vanilla bone angles
 * so they don't fight with our keyframes.
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
        if (!PlayerJsonAnimState.isActive()) return;
        if (!PlayerJsonAnimState.isPlayingOneShot()) return;

        // Zero out vanilla angles — JSON override will set them properly
        body.pitch = 0;     body.yaw = 0;     body.roll = 0;
        head.pitch = 0;     head.yaw = 0;     head.roll = 0;
        rightArm.pitch = 0; rightArm.yaw = 0; rightArm.roll = 0;
        leftArm.pitch = 0;  leftArm.yaw = 0;  leftArm.roll = 0;
        rightLeg.pitch = 0; rightLeg.yaw = 0; rightLeg.roll = 0;
        leftLeg.pitch = 0;  leftLeg.yaw = 0;  leftLeg.roll = 0;
    }
}
