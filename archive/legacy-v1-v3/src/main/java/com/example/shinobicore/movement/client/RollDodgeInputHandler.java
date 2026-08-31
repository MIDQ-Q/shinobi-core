package com.example.shinobicore.movement.client;

import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;

public final class RollDodgeInputHandler {
    private static long lastShiftTime = 0;
    
    public static void tick(ClientPlayerEntity player) {
        boolean shift = MovementInputService.isSneaking(player);
        long now = System.currentTimeMillis();
        
        if (shift && (now - lastShiftTime) < 250) {
            float yaw = player.getYaw();
            float forward = MovementInputService.getForwardInput(player);
            float strafe = MovementInputService.getStrafeInput(player);
            
            if (forward > 0.1f) yaw += 0;
            else if (forward < -0.1f) yaw += 180;
            else if (strafe > 0.1f) yaw += 90;
            else if (strafe < -0.1f) yaw -= 90;
            else { lastShiftTime = now; return; }
            
            DodgeClient.start(player, yaw);
            lastShiftTime = 0; // Prevent spam
        }
        
        if (shift) lastShiftTime = now;
    }
}