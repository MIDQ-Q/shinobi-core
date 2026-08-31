package com.example.shinobicore.modules.movement.client;

import net.minecraft.util.math.Vec3d;


import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.ChargedJumpReleasedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import net.minecraft.client.network.ClientPlayerEntity;

public final class ChargedJumpService {
    private static int chargeTicks = 0;
    private static boolean isCharging = false;

    private ChargedJumpService() {}

    public static void tickCharge(ClientPlayerEntity player) {
        if (isCharging) {
            chargeTicks++;
            ClientMovementState.setPose(MovementPose.CHARGING_JUMP);
            if (chargeTicks >= MovementConfig.CHARGED_JUMP_CHARGE_TICKS) {
                chargeTicks = MovementConfig.CHARGED_JUMP_CHARGE_TICKS;
            }
        }
    }

    public static void startCharge(ClientPlayerEntity player) {
        if (player.isOnGround() && player.getVelocity().horizontalLengthSquared() < 0.01) {
            isCharging = true;
            chargeTicks = 0;
        }
    }

    public static void releaseJump(ClientPlayerEntity player) {
        if (!isCharging) return;
        isCharging = false;
        
        float multiplier = 1.0f + ((float)chargeTicks / MovementConfig.CHARGED_JUMP_CHARGE_TICKS) * (MovementConfig.CHARGED_JUMP_MAX_MULT - 1.0f);
        
        boolean hasChakra = CoreServices.get(ChakraApi.class).map(c -> 
            c.isChakraModeActive(player) && c.trySpend(player, (float) MovementConfig.CHARGED_JUMP_CHAKRA_COST)
        ).orElse(false);

        if (hasChakra) {
            player.jump();
            Vec3d vel = player.getVelocity();
            player.setVelocity(vel.x, vel.y * multiplier, vel.z);
            player.velocityModified = true;
        }
        
        ClientMovementState.setPose(MovementPose.NORMAL);
        ClientMovementController.events().publish(new ChargedJumpReleasedEvent(player, chargeTicks));
        chargeTicks = 0;
    }
    
    public static float getChargeProgress() {
        return (float)chargeTicks / MovementConfig.CHARGED_JUMP_CHARGE_TICKS;
    }
}