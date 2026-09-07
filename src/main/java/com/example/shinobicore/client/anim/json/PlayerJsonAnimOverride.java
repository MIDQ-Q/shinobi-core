package com.example.shinobicore.client.anim.json;

import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.ClientNinjaStateHolder;
import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.render.ShinobiPlayerModel;
import java.util.HashMap;
import java.util.Map;

/**
 * Maps all 11 Blockbench bones to ModelPart references.
 * For extra bones (forearms, shins), stores rotation in standalone parts
 * then applies them additively to parent arms/legs.
 */
public class PlayerJsonAnimOverride {

    public static void apply(AbstractClientPlayerEntity player, BipedEntityModel<?> model,
                             float limbAngle, float limbDistance) {
        Map<String, ModelPart> parts = new HashMap<>();

        // 6 vanilla bones - direct mapping
        parts.put("body", model.body);
        parts.put("head", model.head);
        parts.put("leftArm", model.leftArm);
        parts.put("rightArm", model.rightArm);
        parts.put("leftLeg", model.leftLeg);
        parts.put("rightLeg", model.rightLeg);

        // 5 extra bones - only available in ShinobiPlayerModel
        boolean hasExtraBones = false;
        if (model instanceof ShinobiPlayerModel<?> shinobiModel) {
            hasExtraBones = true;
            shinobiModel.resetExtraBones();
            parts.put("leftForeArm", shinobiModel.leftForeArm);
            parts.put("rightForeArm", shinobiModel.rightForeArm);
            parts.put("leftShin", shinobiModel.leftShin);
            parts.put("rightShin", shinobiModel.rightShin);
            // root bone - skip for now, no visual equivalent in vanilla
        }

        // Determine current animation state
        boolean isMoving = limbDistance > 0.1f;
        boolean isSprinting = player.isSprinting();
        boolean isChakra = ClientNinjaStateHolder.get().isChakraMode() && ChakraHudRenderer.currentChakra > 0;
        boolean isSliding = ParkourManager.isSliding();
        boolean isRolling = ParkourManager.isRolling();

        // Apply JSON animation (writes rotations to all mapped parts)
        // Diagnostics hook
        AnimDiagnostics.onApplyCalled(PlayerJsonAnimState.getCurrentAnim());

        PlayerJsonAnimState.tickAndApply(parts, isMoving, isSprinting, isChakra, isSliding, isRolling);

        // Apply extra bone rotations additively to parent bones
        // Since vanilla arms/legs are single pieces, forearm/shin rotations
        // are added on top of the arm/leg rotations
        if (hasExtraBones && model instanceof ShinobiPlayerModel<?> shinobiModel) {
            // Forearm rotation adds to arm
            model.leftArm.pitch += shinobiModel.leftForeArm.pitch;
            model.leftArm.yaw += shinobiModel.leftForeArm.yaw;
            model.leftArm.roll += shinobiModel.leftForeArm.roll;

            model.rightArm.pitch += shinobiModel.rightForeArm.pitch;
            model.rightArm.yaw += shinobiModel.rightForeArm.yaw;
            model.rightArm.roll += shinobiModel.rightForeArm.roll;

            // Shin rotation adds to leg
            model.leftLeg.pitch += shinobiModel.leftShin.pitch;
            model.leftLeg.yaw += shinobiModel.leftShin.yaw;
            model.leftLeg.roll += shinobiModel.leftShin.roll;

            model.rightLeg.pitch += shinobiModel.rightShin.pitch;
            model.rightLeg.yaw += shinobiModel.rightShin.yaw;
            model.rightLeg.roll += shinobiModel.rightShin.roll;
        }
    }
}