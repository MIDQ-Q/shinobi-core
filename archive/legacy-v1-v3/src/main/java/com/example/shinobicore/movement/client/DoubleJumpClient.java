package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class DoubleJumpClient {
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.doubleJump) return;
        
        if (player.isOnGround() || WaterWalkClient.isActive() || WallRunClient.isActive()) {
            ClientMovementState.resetAirJumps();
            return;
        }
        
        if (MovementInputService.wasJumpPressed() && ClientMovementState.getJumpsLeft() > 0) {
            Vec3d current = player.getVelocity();
            float rad = (float)Math.toRadians(player.getYaw());
            
            double forwardBoost = 1.8;
            double preserve = 0.5;
            double jumpY = 0.95;
            
            double boostX = -Math.sin(rad) * forwardBoost;
            double boostZ = Math.cos(rad) * forwardBoost;
            
            player.setVelocity(
                current.x * preserve + boostX,
                jumpY,
                current.z * preserve + boostZ
            );
            player.velocityModified = true;
            ClientMovementState.useAirJump();
        }
    }
}