package com.example.shinobicore.mixin;

import net.fabricmc.api.EnvType;
import net.fabricmc.api.Environment;

import com.example.shinobicore.client.ClientNinjaState;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.client.render.entity.model.PlayerEntityModel;
import net.minecraft.entity.LivingEntity;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Naruto-Run pose: arms swept back, body tilted forward during sprint.
 * Works for local player AND remote players (pure client-side visual).
 * Activates when sprinting with sufficient horizontal speed.
 * Enhanced in Chakra Mode.
 */
@Environment(EnvType.CLIENT)
@Mixin(PlayerEntityModel.class)
public abstract class NarutoRunMixin extends BipedEntityModel<LivingEntity> {

    @Unique
    private static final float MIN_SPRINT_SPEED = 0.18f;
    @Unique
    private static final float MAX_SPRINT_SPEED = 0.45f;

    // Base pose values (non-chakra)
    @Unique private static final float BASE_BODY_TILT = 0.45f;
    @Unique private static final float BASE_ARM_PITCH = 1.35f;
    @Unique private static final float BASE_ARM_YAW   = 0.18f;
    @Unique private static final float BASE_ARM_ROLL  = 0.22f;
    @Unique private static final float BASE_HEAD_TILT = -0.12f;
    @Unique private static final float BASE_LEG_LIFT  = 0.25f;

    // Chakra-enhanced pose
    @Unique private static final float CHAKRA_BODY_TILT = 0.65f;
    @Unique private static final float CHAKRA_ARM_PITCH = 1.55f;
    @Unique private static final float CHAKRA_ARM_YAW   = 0.22f;
    @Unique private static final float CHAKRA_ARM_ROLL  = 0.28f;
    @Unique private static final float CHAKRA_HEAD_TILT = -0.18f;
    @Unique private static final float CHAKRA_LEG_LIFT  = 0.35f;

    public NarutoRunMixin(ModelPart root) {
        super(root);
    }

    @Inject(
        method = "setAngles(Lnet/minecraft/entity/LivingEntity;FFFFF)V",
        at = @At("TAIL")
    )
    private void shinobicore_applyNarutoRun(
            LivingEntity entity,
            float limbAngle,
            float limbDistance,
            float animationProgress,
            float headYaw,
            float headPitch,
            CallbackInfo ci) {

        if (!(entity instanceof AbstractClientPlayerEntity player)) return;

        // ---- Guards: when NOT to apply ----
        if (!player.isSprinting()) return;
        if (player.isSneaking()) return;
        if (player.isFallFlying()) return;          // elytra
        if (player.isSwimming()) return;
        if (player.isSubmergedInWater()) return;
        if (player.isSleeping()) return;
        if (player.hasVehicle()) return;
        if (player.isUsingItem()) return;           // eating, blocking, etc.

        // Don't override attack swing animation (arm needs to be free)
        if (player.handSwingProgress > 0.05f) return;

        // ---- Speed check ----
        Vec3d vel = player.getVelocity();
        double horizSpeedSq = vel.x * vel.x + vel.z * vel.z;
        if (horizSpeedSq < MIN_SPRINT_SPEED * MIN_SPRINT_SPEED) return;

        float horizSpeed = (float) Math.sqrt(horizSpeedSq);
        float rawIntensity = (horizSpeed - MIN_SPRINT_SPEED) / (MAX_SPRINT_SPEED - MIN_SPRINT_SPEED);
        float intensity = MathHelper.clamp(rawIntensity, 0.0f, 1.0f);

        // Smooth breathing bob while running (classic anime run sway)
        float bob = MathHelper.sin(animationProgress * 0.9f) * 0.04f * intensity;

        // ---- Determine pose values (base or chakra-enhanced) ----
        boolean chakraMode = ClientNinjaState.chakraMode;
        float bodyTilt = chakraMode ? CHAKRA_BODY_TILT : BASE_BODY_TILT;
        float armPitch = chakraMode ? CHAKRA_ARM_PITCH : BASE_ARM_PITCH;
        float armYaw   = chakraMode ? CHAKRA_ARM_YAW   : BASE_ARM_YAW;
        float armRoll  = chakraMode ? CHAKRA_ARM_ROLL  : BASE_ARM_ROLL;
        float headTilt = chakraMode ? CHAKRA_HEAD_TILT : BASE_HEAD_TILT;
        float legLift  = chakraMode ? CHAKRA_LEG_LIFT  : BASE_LEG_LIFT;

        // Apply intensity
        float i = intensity;

        // ---- Body: tilt forward + slight bob ----
        this.body.pitch += bodyTilt * i + bob;
        this.body.roll  += bob * 0.5f;

        // ---- Head: look up slightly (compensate body tilt) ----
        this.head.pitch += headTilt * i;

        // ---- Arms: swept back behind the torso ----
        // Right arm
        this.rightArm.pitch = armPitch * i;
        this.rightArm.yaw   = -armYaw * i;
        this.rightArm.roll  = armRoll * i;

        // Left arm (mirrored)
        this.leftArm.pitch = armPitch * i;
        this.leftArm.yaw   = armYaw * i;
        this.leftArm.roll  = -armRoll * i;

        // ---- Legs: slightly lifted, reduced vanilla swing ----
        // Dampen vanilla leg swing for a "gliding" ninja run feel
        this.rightLeg.pitch *= (1.0f - 0.55f * i);
        this.leftLeg.pitch  *= (1.0f - 0.55f * i);

        // Add subtle alternating knee lift
        float legPhase = MathHelper.sin(animationProgress * 0.9f);
        this.rightLeg.pitch -= legLift * i * (0.5f + 0.5f * legPhase);
        this.leftLeg.pitch  -= legLift * i * (0.5f - 0.5f * legPhase);

        // ---- Hat / overlay layers follow head ----
        this.hat.pitch += headTilt * i;
    }
}