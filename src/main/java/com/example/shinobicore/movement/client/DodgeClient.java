package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class DodgeClient {
    private static boolean active = false;
    private static int ticks = 0;
    private static int cooldown = 0;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        if (!FeatureFlags.dodge) { stop(player); return; }
        
        if (active) {
            ticks++;
            if (ticks > 8) { stop(player); return; }
        }
    }
    
    public static void start(ClientPlayerEntity player, float yaw) {
        if (cooldown > 0 || !player.isOnGround()) return;
        
        active = true;
        ticks = 0;
        cooldown = 30;
        ClientMovementState.setPhase(MovementPhase.DODGING);
        ClientMovementState.setIframeTicks(8);
        
        float rad = (float)Math.toRadians(yaw);
        float strength = 1.6f;
        
        Vec3d current = player.getVelocity();
        player.setVelocity(
            current.x * 0.2 + (-Math.sin(rad) * strength),
            0.35,
            current.z * 0.2 + (Math.cos(rad) * strength)
        );
        player.velocityModified = true;
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ticks = 0;
        if (ClientMovementState.getPhase() == MovementPhase.DODGING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}