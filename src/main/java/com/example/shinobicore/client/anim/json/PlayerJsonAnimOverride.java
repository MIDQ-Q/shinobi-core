package com.example.shinobicore.client.anim.json;

import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.ClientNinjaStateHolder;
import com.example.shinobicore.client.ChakraHudRenderer;
import java.util.HashMap;
import java.util.Map;

public class PlayerJsonAnimOverride {
    public static void apply(AbstractClientPlayerEntity player, BipedEntityModel<?> model, float limbAngle, float limbDistance) {
        Map<String, ModelPart> parts = new HashMap<>();
        parts.put("body", model.body);
        parts.put("head", model.head);
        parts.put("rightArm", model.rightArm);
        parts.put("leftArm", model.leftArm);
        parts.put("rightLeg", model.rightLeg);
        parts.put("leftLeg", model.leftLeg);
        
        boolean isMoving = limbDistance > 0.1f;
        boolean isSprinting = player.isSprinting();
        boolean isChakra = ClientNinjaStateHolder.get().isChakraMode() && ChakraHudRenderer.currentChakra > 0;
        boolean isSliding = ParkourManager.isSliding();
        boolean isRolling = ParkourManager.isRolling();
        
        PlayerJsonAnimState.tickAndApply(parts, isMoving, isSprinting, isChakra, isSliding, isRolling);
    }
}