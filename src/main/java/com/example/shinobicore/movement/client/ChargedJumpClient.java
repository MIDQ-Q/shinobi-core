package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.client.ClientNinjaState;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class ChargedJumpClient {
    private static boolean charging = false;
    private static int chargeTicks = 0;
    
    public static boolean isCharging() { return charging; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.chargedJump) return;
        if (!ClientNinjaState.chakraMode || !player.isOnGround()) {
            charging = false;
            chargeTicks = 0;
            return;
        }
        
        boolean jumpHeld = player.input.jumping;
        
        if (jumpHeld) {
            charging = true;
            chargeTicks++;
            if (chargeTicks > 40) chargeTicks = 40;
            
            // Slow down while charging
            Vec3d v = player.getVelocity();
            player.setVelocity(v.x * 0.8, v.y, v.z * 0.8);
            player.velocityModified = true;
        } else if (charging) {
            // Release
            if (chargeTicks >= 5) {
                float ratio = (float)chargeTicks / 40.0f;
                float mult = 1.0f + (ratio * 2.0f); // Up to x3
                
                Vec3d v = player.getVelocity();
                double newY = Math.min(v.y * mult, 1.5); // Cap
                
                player.setVelocity(v.x, newY, v.z);
                player.velocityModified = true;
            }
            charging = false;
            chargeTicks = 0;
        }
    }
}