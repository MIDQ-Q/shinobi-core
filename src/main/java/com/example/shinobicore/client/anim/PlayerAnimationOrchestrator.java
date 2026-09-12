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
import com.example.shinobicore.client.anim.json.PlayerJsonAnimOverride;
import com.example.shinobicore.client.anim.json.PlayerJsonAnimState;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.util.math.MathHelper;

public final class PlayerAnimationOrchestrator {
    private PlayerAnimationOrchestrator() {}

    public static void apply(AbstractClientPlayerEntity player, BipedEntityModel<?> model,
            float limbAngle, float limbDistance, float animationProgress) {
        if (HitStopManager.isFrozen(player.getId())) return;

        // === MASTER PATCH: JSON animation layer ===
        PlayerJsonAnimOverride.apply(player, model, limbAngle, limbDistance);
        
        // Hurt animations override
        if (!PlayerJsonAnimState.isPlayingOneShot()
                && player.hurtTime == player.maxHurtTime && player.maxHurtTime > 0) {
            PlayerJsonAnimState.play(player.getHealth() / player.getMaxHealth() < 0.35f ? "hurt_heavy" : "hurt_light", true);
        }

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
        
        // Water run (Hardcoded override)
        if (chakraMode && ChakraPhysicsClient.standingOnWater && sprinting) {
            applyWaterRun(limbAngle, limbDistance, rightArm, leftArm, body, head, rightLeg, leftLeg);
            return;
        }

        // Wall run (Movement Pack: фаза от пройденного пути — ноги не «умирают» в воздухе)
        if (ParkourManager.isWallRunning()) {
            applyWallRun(limbAngle, limbDistance, rightArm, leftArm, body, head, rightLeg, leftLeg);
            return;
        }

        // Wall climb (Movement Pack: цикл карабканья вместо застывшей позы прилипания)
        if (ChakraPhysicsClient.stickingToWall
                && com.example.shinobicore.client.movement.MovementFeel.isWallClimbing()) {
            applyWallClimb(rightArm, leftArm, body, head, rightLeg, leftLeg);
            return;
        }

                // We skip hardcoded poses for them to prevent fighting with JSON keyframes.

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

        // Idle poses (Only for meditation or wall stick, others handled by JSON idle/combat_idle)
        boolean isJsonOneShot = PlayerJsonAnimState.isPlayingOneShot();
        if (!TaijutsuAnimations.isAttacking(player) && !TaijutsuAnimations.isKicking(player) 
            && !KenjutsuAnimations.isAttacking(player) && !isJsonOneShot) {
            if (ClientNinjaStateHolder.get().isMeditating() || (ChakraPhysicsClient.stickingToWall && !com.example.shinobicore.client.movement.MovementFeel.isWallClimbing())) { 
                IdlePoseSystem.apply(player, model, limbDistance, animationProgress); 
            }
        }
    }

    private static void applyWaterRun(float limbAngle, float limbDistance,
            ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head,
            ModelPart rLeg, ModelPart lLeg) {
        // Movement Pack (1.1.4): бег по воде как в аниме — корпус низко и вперёд,
        // руки отведены назад, шаг укороченный и учащённый (cycle x1.45),
        // лёгкое встречное покачивание корпуса и «компенсация» головой.
        float cycle = limbAngle * 1.45f;
        float amp = MathHelper.clamp(limbDistance * 1.25f, 0.25f, 1.4f);
        float bob = MathHelper.sin(cycle * 2.0f) * 0.05f * amp;
        body.pitch = 0.42f + bob * 0.4f;
        body.roll = MathHelper.sin(cycle) * 0.035f;
        head.pitch -= 0.40f;
        rArm.pitch = -0.55f + bob;
        rArm.yaw = -0.32f;
        rArm.roll = 0.16f;
        lArm.pitch = -0.55f - bob;
        lArm.yaw = 0.32f;
        lArm.roll = -0.16f;
        float swing = MathHelper.cos(cycle) * amp * 1.15f;
        rLeg.pitch = swing - 0.10f;
        lLeg.pitch = -swing - 0.10f;
        rLeg.yaw = -0.10f;
        lLeg.yaw = 0.10f;
    }

    private static void applyWallRun(float limbAngle, float limbDistance,
            ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head,
            ModelPart rLeg, ModelPart lLeg) {
        // Movement Pack (1.1.4): фаза цикла берётся из MovementFeel (накоплена
        // по ПРОЙДЕННОМУ ПУТИ) — раньше использовался limbAngle, который в
        // воздухе обнуляется, и ноги «застывали»: бег выглядел как ползание.
        // Наклон корпуса теперь в сторону стены (wallSide), а не константой.
        float phase = com.example.shinobicore.client.movement.MovementFeel.getWallRunPhase();
        float side = com.example.shinobicore.client.movement.MovementFeel.getWallSide();
        float swing = MathHelper.sin(phase) * 1.0f;
        body.roll = side * 0.40f;
        body.pitch = 0.30f;
        rArm.pitch = -0.95f + swing * 0.55f;
        lArm.pitch = -0.95f - swing * 0.55f;
        rArm.yaw = side > 0 ? -0.55f : -0.22f;
        lArm.yaw = side > 0 ? 0.22f : 0.55f;
        rArm.roll = 0.22f;
        lArm.roll = -0.22f;
        head.yaw = side * 0.28f;
        head.pitch -= 0.24f;
        head.roll = -side * 0.16f;
        rLeg.pitch = swing - 0.12f;
        lLeg.pitch = -swing * 0.85f - 0.12f;
        rLeg.yaw = -0.07f;
        lLeg.yaw = 0.07f;
    }

    /**
     * Movement Pack (1.1.4): цикл карабканья по стене (вертикальный подъём).
     * Руки поочерёдно тянутся вверх и подтягиваются, ноги толкают в противофазе.
     * Фаза — из MovementFeel.getClimbPhase() (накоплена по высоте подъёма),
     * поэтому частота движений совпадает с реальной скоростью.
     */
    private static void applyWallClimb(ModelPart rArm, ModelPart lArm, ModelPart body,
            ModelPart head, ModelPart rLeg, ModelPart lLeg) {
        float phase = com.example.shinobicore.client.movement.MovementFeel.getClimbPhase();
        float s1 = MathHelper.sin(phase);
        float s2 = MathHelper.sin(phase + (float) Math.PI);
        body.pitch = -0.14f;
        body.roll = 0f;
        head.pitch = 0.30f;
        rArm.pitch = -2.25f + s1 * 0.85f;
        lArm.pitch = -2.25f + s2 * 0.85f;
        rArm.yaw = -0.22f;
        lArm.yaw = 0.22f;
        rArm.roll = 0.10f;
        lArm.roll = -0.10f;
        rLeg.pitch = -0.45f + s2 * 0.50f;
        lLeg.pitch = -0.45f + s1 * 0.50f;
        rLeg.yaw = -0.10f;
        lLeg.yaw = 0.10f;
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
