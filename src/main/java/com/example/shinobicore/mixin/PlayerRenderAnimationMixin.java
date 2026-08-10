package com.example.shinobicore.mixin;

import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.combat.TaijutsuAnimations.AttackAnimationState;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.entity.LivingEntity;
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

    @Inject(method = "setAngles", at = @At("TAIL"))
    private void shinobicore_applyCombatAnimations(LivingEntity entity, float limbAngle, float limbDistance,
                                                   float animationProgress, float headYaw, float headPitch,
                                                   CallbackInfo ci) {
        
        if (!(entity instanceof AbstractClientPlayerEntity player)) return;
        
        // === АНИМАЦИЯ УДАРА РУКОЙ ===
        AttackAnimationState attackState = TaijutsuAnimations.getAnimationState(player);
        if (attackState != null) {
            int step = attackState.comboStep;
            float progress = attackState.getProgress();
            
            // Плавная анимация: замах -> удар -> возврат
            float armRotation = 0f;
            if (progress < 0.3f) {
                // Замах (0 -> 0.3)
                armRotation = (float) Math.sin(progress / 0.3f * Math.PI / 2) * -120f;
            } else if (progress < 0.6f) {
                // Удар (0.3 -> 0.6)
                armRotation = -120f;
            } else {
                // Возврат (0.6 -> 1.0)
                float returnProgress = (progress - 0.6f) / 0.4f;
                armRotation = -120f * (1f - returnProgress);
            }
            
            // Чередование рук: четные шаги - правая, нечетные - левая
            boolean useRightArm = (step % 2 == 0);
            float armRadians = armRotation * 0.0174533f;
            
            if (useRightArm) {
                rightArm.pitch += armRadians;
            } else {
                leftArm.pitch += armRadians;
            }
            
            // Небольшой поворот тела в сторону удара
            float bodyYaw = armRotation * 0.2f * 0.0174533f;
            body.yaw += bodyYaw;
        }
        
        // === АНИМАЦИЯ УДАРА НОГОЙ ===
        if (TaijutsuAnimations.isKicking(player)) {
            float kickProgress = TaijutsuAnimations.getKickState(player).getProgress();
            
            // Лоу-кик: наклон корпуса вперед + удар правой ногой вперед-вниз
            float kickAngle = 0f;
            float bodyLean = 0f;
            
            if (kickProgress < 0.3f) {
                // Замах (0 -> 0.3)
                float p = kickProgress / 0.3f;
                kickAngle = (float) Math.sin(p * Math.PI / 2) * -90f;
                bodyLean = (float) Math.sin(p * Math.PI / 2) * 20f;
            } else if (kickProgress < 0.6f) {
                // Удар (0.3 -> 0.6)
                kickAngle = -90f;
                bodyLean = 20f;
            } else {
                // Возврат (0.6 -> 1.0)
                float returnProgress = (kickProgress - 0.6f) / 0.4f;
                kickAngle = -90f * (1f - returnProgress);
                bodyLean = 20f * (1f - returnProgress);
            }
            
            float kickRadians = kickAngle * 0.0174533f;
            float bodyRadians = bodyLean * 0.0174533f;
            
            // Правая нога вперед-вниз (лоу-кик)
            rightLeg.pitch += kickRadians;
            rightLeg.roll += kickRadians * 0.2f;
            
            // Левая нога слегка назад для баланса
            leftLeg.pitch -= kickRadians * 0.3f;
            
            // Корпус наклоняется вперед
            body.pitch += bodyRadians;
            
            // Руки для баланса - противоположно ноге
            rightArm.pitch -= kickRadians * 0.3f;
            leftArm.pitch += kickRadians * 0.4f;
        }
    }
}