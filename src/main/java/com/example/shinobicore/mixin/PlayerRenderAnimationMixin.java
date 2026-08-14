package com.example.shinobicore.mixin;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.combat.KenjutsuAnimations;
import com.example.shinobicore.client.IdlePoseSystem;
import com.example.shinobicore.client.combat.TaijutsuAnimations.AttackAnimationState;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.client.combat.HitStopManager;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.entity.LivingEntity;
import net.minecraft.util.math.MathHelper;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(BipedEntityModel.class)
public abstract class PlayerRenderAnimationMixin {
    @Shadow public ModelPart rightArm;
    @Shadow public ModelPart leftArm;
    @Shadow public ModelPart rightLeg;
    @Shadow public ModelPart leftLeg;
    @Shadow public ModelPart body;
    @Shadow public ModelPart head;

    @Inject(method = "setAngles", at = @At("TAIL"))
    private void shinobicore_applyAnimations(LivingEntity entity, float limbAngle, float limbDistance,
                                              float animationProgress, float headYaw, float headPitch,
                                              CallbackInfo ci) {
        if (!(entity instanceof AbstractClientPlayerEntity player)) return;
        // === HIT-STOP: freeze animation on hit ===
        if (HitStopManager.isFrozen(entity.getId())) {
            return;
        }

        boolean chakraMode = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        boolean sprinting = player.isSprinting();
        boolean sliding = ParkourManager.isSliding();
        boolean rolling = ParkourManager.isRolling();

        // === НАРУТО-РАН в чакра-режиме ===
                // === РќРђР РЈРўРћ-Р РђРќ DEBUG ===
        boolean narutoRunCondition = chakraMode && sprinting && !sliding && !rolling;
        boolean standingOnWater = com.example.shinobicore.client.ChakraPhysicsClient.standingOnWater;
        boolean wallRunning = com.example.shinobicore.client.parkour.ParkourManager.isWallRunning();
        
        if (player.isSprinting() && chakraMode) {
            com.example.shinobicore.ShinobiCore.LOGGER.info("[NARUTO-RUN DEBUG] chakraMode={}, sprinting={}, sliding={}, rolling={}, standingOnWater={}, wallRunning={}", 
                chakraMode, sprinting, sliding, rolling, standingOnWater, wallRunning);
            com.example.shinobicore.ShinobiCore.LOGGER.info("[NARUTO-RUN DEBUG] narutoRunCondition={}, currentChakra={}", 
                narutoRunCondition, ChakraHudRenderer.currentChakra);
        }
        
        // === WATER RUNNING === // BATCH3_WATER
        if (chakraMode && com.example.shinobicore.client.ChakraPhysicsClient.standingOnWater && sprinting) {
            applyWaterRun(limbAngle, limbDistance);
            return;
        }
        // === WALL RUNNING === // BATCH3_WALL
        if (com.example.shinobicore.client.parkour.ParkourManager.isWallRunning()) {
            applyWallRun(limbAngle, limbDistance);
            return;
        }
        // === SLIDING === // BATCH3_SLIDE
        if (sliding) {
            applySlidePose();
            return;
        }
        if (chakraMode && sprinting && !sliding && !rolling) {
            applyNarutoRun(limbAngle, limbDistance);
            return; // Не применяем обычную анимацию
        }

        // === Обычная ходьба/бег ===
        if (!sliding && !rolling) {
            applyEnhancedWalkRunAnimations(player, limbAngle, limbDistance, sprinting);
        }

        // === АНИМАЦИЯ ТАЙ-ДЗЮЦУ (удары руками) ===
        AttackAnimationState attackState = TaijutsuAnimations.getAnimationState(player);
        if (attackState != null) {
            applyTaijutsuAttackAnimation(player, attackState);
        }

        // === АНИМАЦИЯ УДАРА НОГОЙ ===
        // === РџР•Р§РђРўР РџР Р РљРђРЎРўР• ===
        // PHASE_E_GENJUTSU_POSE
     var castState = com.example.shinobicore.client.CastingClientState.get(player); // BATCH3_HANDSEAL
        if (castState != null) {
            com.example.shinobicore.client.combat.HandSealPoses.apply(castState.nature, rightArm, leftArm, body, head);
            // BATCH3: nature-specific
            // BATCH3: hand seals
        }
        // === KENJUTSU: SLASH / DEFLECT ===
        if (KenjutsuAnimations.isDeflecting(player) || ClientNinjaState.deflectHeld) {
            KenjutsuAnimations.applyDeflect(player, rightArm, leftArm);
        }
        if (KenjutsuAnimations.isAttacking(player)) {
            KenjutsuAnimations.applySlash(player, rightArm, leftArm, body, head);
        }
        // === PHASE_A_APPLY: throw / landing / chakra burst ===
        com.example.shinobicore.client.combat.ThrowAnimations.apply(player, rightArm, leftArm, body, head);
        com.example.shinobicore.client.LandingAnimations.apply(player, body, rightLeg, leftLeg, rightArm, leftArm, head);
        com.example.shinobicore.client.combat.ChakraBurstAnimations.apply(player, rightArm, leftArm, body, head);
        if (com.example.shinobicore.client.combat.ThrowAnimations.isThrowing(player)) {
            com.example.shinobicore.client.combat.ThrowAnimations.apply(player, rightArm, leftArm, body, head);
        }
        // === PHASE E: TAIJUTSU VARIANTS ===
        if (com.example.shinobicore.client.combat.TaichiComboVariants.isActive(player)) {
            com.example.shinobicore.client.combat.TaichiComboVariants.apply(player, rightArm, leftArm, rightLeg, leftLeg, body, head);
            return;
        }
        if (TaijutsuAnimations.isKicking(player)) {
            applyKickAnimation(player);
        }
        // === IDLE POSE SYSTEM ===
        if (!TaijutsuAnimations.isAttacking(player) && !TaijutsuAnimations.isKicking(player)) {
            IdlePoseSystem.apply(player, (BipedEntityModel<?>) (Object) this, limbDistance, animationProgress);
        }
    }

    /**
     * === НАРУТО-РАН: руки вытянуты назад, корпус наклонён ===
     * Каноничная анимация бега из аниме:
     * - Руки почти горизонтально назад
     * - Ладони направлены назад (yaw разведён в стороны)
     * - Корпус сильно наклонён вперёд
     * - Голова слегка задрана (компенсация наклона тела)
     */
    private void applyNarutoRun(float limbAngle, float limbDistance) {
        // Небольшая болтанка рук (руки не статичны, а слегка качаются при беге)
        float bobbing = MathHelper.sin(limbAngle * 2.0f) * 0.08f * limbDistance;

        // === РУКИ: горизонтально назад ===
        // -1.5f рад ≈ -86° (почти горизонтально назад)
        // -1.3f рад ≈ -74° (чуть согнуты, более естественно)
        float armPitchBack = 1.35f + bobbing;

        rightArm.pitch = armPitchBack;
        leftArm.pitch = armPitchBack;

        // Руки разведены в стороны (ладони смотрят назад)
        // yaw > 0 для правой руки = рука вправо
        // yaw < 0 для левой руки = рука влево
        rightArm.yaw = -0.35f;  // правая рука чуть влево (к центру спины)
        leftArm.yaw = 0.35f;    // левая рука чуть вправо (к центру спины)

        // Лёгкий roll чтобы руки выглядели расслабленными
        rightArm.roll = 0.15f;
        leftArm.roll = -0.15f;

        // === КОРПУС: сильный наклон вперёд ===
        body.pitch = 0.55f;
        body.yaw = 0f;
        body.roll = 0f;

        // === ГОЛОВА: компенсируем наклон тела ===
        // Голова должна смотреть вперёд, поэтому "задираем" её вверх
        // относительно тела (head.pitch уменьшается)
        head.pitch -= 0.15f;

        // === НОГИ: более размашистые движения при быстром беге ===
        // Ноги остаются от ванильной анимации, но добавим больше амплитуды
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.4f;
        rightLeg.pitch = legSwing;
        leftLeg.pitch = -legSwing;
    }

    private void applyEnhancedWalkRunAnimations(AbstractClientPlayerEntity player, float limbAngle, float limbDistance,
                                                 boolean sprinting) {
        float speedMultiplier = sprinting ? 1.5f : 1.0f;
        float armSwingAmplitude = limbDistance * 0.8f * speedMultiplier;
        float legSwingAmplitude = limbDistance * 1.2f * speedMultiplier;

        if (sprinting) {
            // Обычный спринт (не чакра-режим) — динамичный бег с согнутыми руками
            rightArm.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * armSwingAmplitude * 1.3f;
            leftArm.pitch = MathHelper.cos(limbAngle) * armSwingAmplitude * 1.3f;

            body.pitch = 0.15f;

            rightLeg.pitch = MathHelper.cos(limbAngle) * legSwingAmplitude * 1.2f;
            leftLeg.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * legSwingAmplitude * 1.2f;

            rightArm.yaw = 0.1f;
            leftArm.yaw = -0.1f;

        } else {
            // Обычная ходьба
            rightArm.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * armSwingAmplitude * 0.8f;
            leftArm.pitch = MathHelper.cos(limbAngle) * armSwingAmplitude * 0.8f;

            body.pitch = 0.05f;

            rightLeg.pitch = MathHelper.cos(limbAngle) * legSwingAmplitude;
            leftLeg.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * legSwingAmplitude;

            body.yaw = MathHelper.sin(limbAngle) * 0.05f;
        }
    }

    private void applyTaijutsuAttackAnimation(AbstractClientPlayerEntity player, AttackAnimationState attackState) {
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

        if (useRightArm) {
            rightArm.pitch += armRadians;
        } else {
            leftArm.pitch += armRadians;
        }

        float bodyYaw = armRotation * 0.2f * 0.0174533f;
        body.yaw += bodyYaw;
    }

    private void applyKickAnimation(AbstractClientPlayerEntity player) {
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
            kickAngle = -90f;
            bodyLean = 20f;
        } else {
            float returnProgress = (kickProgress - 0.6f) / 0.4f;
            kickAngle = -90f * (1f - returnProgress);
            bodyLean = 20f * (1f - returnProgress);
        }

        float kickRadians = kickAngle * 0.0174533f;
        float bodyRadians = bodyLean * 0.0174533f;

        rightLeg.pitch += kickRadians;
        rightLeg.roll += kickRadians * 0.2f;
        leftLeg.pitch -= kickRadians * 0.3f;
        body.pitch += bodyRadians;
        rightArm.pitch -= kickRadians * 0.3f;
        leftArm.pitch += kickRadians * 0.4f;
    }

    // === BATCH 3: Water Run / Wall Run / Slide Poses ===
    private void applyWaterRun(float limbAngle, float limbDistance) {
        float bob = MathHelper.sin(limbAngle * 2.0f) * 0.1f * limbDistance;
        rightArm.pitch = -0.3f + bob;
        rightArm.yaw = -0.9f;
        rightArm.roll = 0.3f;
        leftArm.pitch = -0.3f + bob;
        leftArm.yaw = 0.9f;
        leftArm.roll = -0.3f;
        body.pitch = 0.25f;
        head.pitch -= 0.15f;
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.3f;
        rightLeg.pitch = legSwing;
        rightLeg.yaw = -0.15f;
        leftLeg.pitch = -legSwing;
        leftLeg.yaw = 0.15f;
    }

    private void applyWallRun(float limbAngle, float limbDistance) {
        body.roll = 0.3f;
        body.pitch = 0.2f;
        rightArm.pitch = -1.5f;
        rightArm.yaw = -0.8f;
        rightArm.roll = 0.5f;
        leftArm.pitch = 0.5f;
        leftArm.yaw = 0.5f;
        head.yaw += 0.2f;
        head.pitch -= 0.1f;
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.2f;
        rightLeg.pitch = legSwing;
        leftLeg.pitch = -legSwing;
    }

    private void applySlidePose() {
        rightLeg.pitch = -1.0f;
        rightLeg.yaw = 0.1f;
        leftLeg.pitch = -0.7f;
        leftLeg.yaw = -0.1f;
        body.pitch = -0.4f;
        body.roll = 0.05f;
        rightArm.pitch = 0.6f;
        rightArm.yaw = -0.3f;
        leftArm.pitch = 0.6f;
        leftArm.yaw = 0.3f;
        head.pitch -= 0.2f;
    }
}