package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;

public final class MeditationClient {
    private static boolean active = false;
    private static long lastToggleTime = 0;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.meditation) { stop(player); return; }
        
        if (active) {
            if (MovementInputService.isMoving(player) || player.hurtTime > 0) {
                stop(player);
                return;
            }
            ClientMovementState.setPhase(MovementPhase.MEDITATING);
        }
    }
    
    // Called by Keybind (M)
    public static void toggle(ClientPlayerEntity player) {
        long now = System.currentTimeMillis();
        if (now - lastToggleTime < 200) return;
        lastToggleTime = now;
        
        if (active) {
            stop(player);
        } else {
            if (player.isOnGround() && !MovementInputService.isMoving(player)) {
                active = true;
                ClientMovementState.setPhase(MovementPhase.MEDITATING);
            }
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        if (ClientMovementState.getPhase() == MovementPhase.MEDITATING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}