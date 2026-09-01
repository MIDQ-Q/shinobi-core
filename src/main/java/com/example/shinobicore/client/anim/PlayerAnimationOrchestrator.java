package com.example.shinobicore.client.anim;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ChakraPhysicsClient;
import com.example.shinobicore.client.ClientNinjaStateHolder;
import com.example.shinobicore.client.CastingClientState;
import com.example.shinobicore.client.IdlePoseSystem;
import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.combat.KenjutsuAnimations;
import com.example.shinobicore.client.combat.HitStopManager;
import com.example.shinobicore.client.combat.HandSealPoses;
import com.example.shinobicore.client.combat.TaichiComboVariants;
import com.example.shinobicore.client.combat.ThrowAnimations;
import com.example.shinobicore.client.combat.ChakraBurstAnimations;
import com.example.shinobicore.client.LandingAnimations;
import com.example.shinobicore.client.parkour.ParkourManager;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.util.math.MathHelper;

public final class PlayerAnimationOrchestrator {
    private PlayerAnimationOrchestrator() {}

    public static void apply(AbstractClientPlayerEntity player, BipedEntityModel<?> model,
            float limbAngle, float limbDistance, float animationProgress) {
        if (HitStopManager.isFrozen(player.getId())) return;

        ModelPart rightArm = model.rightArm;
        ModelPart leftArm = model.leftArm;
        ModelPart rightLeg = model.rightLeg;
        ModelPart leftLeg = model.leftLeg;
        ModelPart body = model.body;
        ModelPart head = model.head;

        var state = ClientNinjaStateHolder.get();
        boolean chakraMode = state.isChakraMode() && ChakraHudRenderer.currentChakra > 0;
        boolean sprinting = player.isSprinting();
        boolean sliding = ParkourManager.isSliding();
        boolean rolling = ParkourManager.isRolling();

        // Water run
        if (chakraMode && ChakraPhysicsClient.standingOnWater && sprinting) {
            applyWaterRun(limbAngle, limbDistance, rightArm, leftArm, body, head, rightLeg, leftLeg);
            return;
        }

        // Wall run
        if (ParkourManager.isWallRunning()) {
            applyWallRun(limbAngle, limbDistance, rightArm, leftArm, body, head, rightLeg, leftLeg);
            return;
        }

        // Slide
        if (sliding) {
            applySlidePose(rightArm, leftArm, body, head, rightLeg, leftLeg);
            return;
        }

        // Naruto run
        if (chakraMode && sprinting && !sliding && !rolling) {
            applyNarutoRun(limbAngle, limbDistance, rightArm, leftArm, body, head, rightLeg, leftLeg);
            return;
        }

        // Normal walk/run
        if (!sliding && !rolling) {
            applyEnhancedWalkRun(limbAngle, limbDistance, sprinting, rightArm, leftArm, body, rightLeg, leftLeg);
        }

        // Taijutsu attack animation
        TaijutsuAnimations.AttackAnimationState attackState = TaijutsuAnimations.getAnimationState(player);
        if (attackState != null) {
            applyTaijutsuAttack(attackState, rightArm, leftArm, body);
        }

        // Hand seals
        CastingClientState.Cast castState = CastingClientState.get(player);
        if (castState != null) {
            HandSealPoses.apply(castState.nature, rightArm, leftArm, body, head);
        }

        // Kenjutsu
        if (KenjutsuAnimations.isDeflecting(player) || state.isDeflectHeld()) {
            KenjutsuAnimations.applyDeflect(player, rightArm, leftArm);
        }
        if (KenjutsuAnimations.isAttacking(player)) {
            KenjutsuAnimations.applySlash(player, rightArm, leftArm, body, head);
        }

        // Throw / Landing / Chakra burst
        ThrowAnimations.apply(player, rightArm, leftArm, body, head);
        LandingAnimations.apply(player, body, rightLeg, leftLeg, rightArm, leftArm, head);
        ChakraBurstAnimations.apply(player, rightArm, leftArm, body, head);

        // Taichi combo variants
        if (TaichiComboVariants.isActive(player)) {
            TaichiComboVariants.apply(player, rightArm, leftArm, rightLeg, leftLeg, body, head);
            return;
        }

        // Kick
        if (TaijutsuAnimations.isKicking(player)) {
            applyKickAnimation(player, rightArm, leftArm, body, rightLeg, leftLeg);
        }

        // Idle poses
        if (!TaijutsuAnimations.isAttacking(player) && !TaijutsuAnimations.isKicking(player)) {
            IdlePoseSystem.apply(player, model, limbDistance, animationProgress);
        }
    }

    private static void applyWaterRun(float limbAngle, float limbDistance,
            ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head,
            ModelPart rLeg, ModelPart lLeg) {
        float bob = MathHelper.sin(limbAngle * 2.0f) * 0.1f * limbDistance;
        rArm.pitch = -0.3f + bob; rArm.yaw = -0.9f; rArm.roll = 0.3f;
        lArm.pitch = -0.3f + bob; lArm.yaw = 0.9f; lArm.roll = -0.3f;
        body.pitch = 0.25f;
        head.pitch -= 0.15f;
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.3f;
        rLeg.pitch = legSwing; rLeg.yaw = -0.15f;
        lLeg.pitch = -legSwing; lLeg.yaw = 0.15f;
    }

    private static void applyWallRun(float limbAngle, float limbDistance,
            ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head,
            ModelPart rLeg, ModelPart lLeg) {
        body.roll = 0.3f; body.pitch = 0.2f;
        rArm.pitch = -1.5f; rArm.yaw = -0.8f; rArm.roll = 0.5f;
        lArm.pitch = 0.5f; lArm.yaw = 0.5f;
        head.yaw += 0.2f; head.pitch -= 0.1f;
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.2f;
        rLeg.pitch = legSwing; lLeg.pitch = -legSwing;
    }

    private static void applySlidePose(ModelPart rArm, ModelPart lArm, ModelPart body,
            ModelPart head, ModelPart rLeg, ModelPart lLeg) {
        rLeg.pitch = -1.0f; rLeg.yaw = 0.1f;
        lLeg.pitch = -0.7f; lLeg.yaw = -0.1f;
        body.pitch = -0.4f; body.roll = 0.05f;
        rArm.pitch = 0.6f; rArm.yaw = -0.3f;
        lArm.pitch = 0.6f; lArm.yaw = 0.3f;
        head.pitch -= 0.2f;
    }

    private static void applyNarutoRun(float limbAngle, float limbDistance,
            ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head,
            ModelPart rLeg, ModelPart lLeg) {
        float bobbing = MathHelper.sin(limbAngle * 2.0f) * 0.08f * limbDistance;
        float armPitchBack = 1.35f + bobbing;
        rArm.pitch = armPitchBack; lArm.pitch = armPitchBack;
        rArm.yaw = -0.35f; lArm.yaw = 0.35f;
        rArm.roll = 0.15f; lArm.roll = -0.15f;
        body.pitch = 0.55f; body.yaw = 0f; body.roll = 0f;
        head.pitch -= 0.15f;
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.4f;
        rLeg.pitch = legSwing; lLeg.pitch = -legSwing;
    }

    private static void applyEnhancedWalkRun(float limbAngle, float limbDistance, boolean sprinting,
            ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart rLeg, ModelPart lLeg) {
        float speedMultiplier = sprinting ? 1.5f : 1.0f;
        float armSwingAmplitude = limbDistance * 0.8f * speedMultiplier;
        float legSwingAmplitude = limbDistance * 1.2f * speedMultiplier;
        if (sprinting) {
            rArm.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * armSwingAmplitude * 1.3f;
            lArm.pitch = MathHelper.cos(limbAngle) * armSwingAmplitude * 1.3f;
            body.pitch = 0.15f;
            rLeg.pitch = MathHelper.cos(limbAngle) * legSwingAmplitude * 1.2f;
            lLeg.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * legSwingAmplitude * 1.2f;
            rArm.yaw = 0.1f; lArm.yaw = -0.1f;
        } else {
            rArm.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * armSwingAmplitude * 0.8f;
            lArm.pitch = MathHelper.cos(limbAngle) * armSwingAmplitude * 0.8f;
            body.pitch = 0.05f;
            rLeg.pitch = MathHelper.cos(limbAngle) * legSwingAmplitude;
            lLeg.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * legSwingAmplitude;
            body.yaw = MathHelper.sin(limbAngle) * 0.05f;
        }
    }

    private static void applyTaijutsuAttack(TaijutsuAnimations.AttackAnimationState attackState,
            ModelPart rArm, ModelPart lArm, ModelPart body) {
        int step = attackState.comboStep;
        float progress = attackState.getProgress();
        float armRotation = 0f;
        if (progress < 0.3f) {
            armRotation = (float) Math.sin(progress / 0.3f * Math.PI / 2) * -120f;
        } else if (progress < 0.6f) {
            armRotation = -120f;
        } else {
            float returnProgress = (progress - 0.6f) / 0.4f;
            armRotation = -120f * (1f - returnProgress);
        }
        boolean useRightArm = (step % 2 == 0);
        float armRadians = armRotation * 0.0174533f;
        if (useRightArm) rArm.pitch += armRadians;
        else lArm.pitch += armRadians;
        float bodyYaw = armRotation * 0.2f * 0.0174533f;
        body.yaw += bodyYaw;
    }

    private static void applyKickAnimation(AbstractClientPlayerEntity player,
            ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart rLeg, ModelPart lLeg) {
        TaijutsuAnimations.KickAnimationState kickState = TaijutsuAnimations.getKickState(player);
        if (kickState == null) return;
        float kickProgress = kickState.getProgress();
        float kickAngle = 0f;
        float bodyLean = 0f;
        if (kickProgress < 0.3f) {
            float p = kickProgress / 0.3f;
            kickAngle = (float) Math.sin(p * Math.PI / 2) * -90f;
            bodyLean = (float) Math.sin(p * Math.PI / 2) * 20f;
        } else if (kickProgress < 0.6f) {
            kickAngle = -90f; bodyLean = 20f;
        } else {
            float returnProgress = (kickProgress - 0.6f) / 0.4f;
            kickAngle = -90f * (1f - returnProgress);
            bodyLean = 20f * (1f - returnProgress);
        }
        float kickRadians = kickAngle * 0.0174533f;
        float bodyRadians = bodyLean * 0.0174533f;
        rLeg.pitch += kickRadians; rLeg.roll += kickRadians * 0.2f;
        lLeg.pitch -= kickRadians * 0.3f;
        body.pitch += bodyRadians;
        rArm.pitch -= kickRadians * 0.3f;
        lArm.pitch += kickRadians * 0.4f;
    }
}